"""Anomaly Detection Service – detects anomalies in renewable energy telemetry."""
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional
import boto3
from botocore.exceptions import ClientError
import numpy as np
from sklearn.ensemble import IsolationForest
from pydantic import BaseModel, Field
import json
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─── AWS / LocalStack configuration ─────────────────────────────────────────
AWS_ENDPOINT = os.getenv("AWS_ENDPOINT_URL")  # None → real AWS; set → LocalStack
REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
DYNAMODB_TABLE_TELEMETRY = os.getenv("DYNAMODB_TABLE_TELEMETRY", "Telemetry")
DYNAMODB_TABLE_ANOMALIES = os.getenv("DYNAMODB_TABLE_ANOMALIES", "Anomalies")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL", "")
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "")

boto_kwargs: Dict[str, Any] = {"region_name": REGION}
if AWS_ENDPOINT:
    boto_kwargs["endpoint_url"] = AWS_ENDPOINT

dynamodb = boto3.resource("dynamodb", **boto_kwargs)
sqs_client = boto3.client("sqs", **boto_kwargs)
sns_client = boto3.client("sns", **boto_kwargs)

# ─── Models ──────────────────────────────────────────────────────────────────

class TelemetryData(BaseModel):
    asset_id: str
    timestamp: datetime
    type: str
    metrics: Dict[str, float]
    source: str = "sensor"

class AnomalyDetectionRequest(BaseModel):
    telemetry_data: TelemetryData
    historical_window_minutes: int = 60

class Anomaly(BaseModel):
    asset_id: str
    timestamp: datetime
    metric_name: str
    value: float
    threshold: float
    severity: str
    recommendations: List[str]

# ─── FastAPI App ──────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Anomaly Detection Service")
    asyncio.create_task(consume_telemetry_events())
    yield
    logger.info("Shutting down Anomaly Detection Service")

app = FastAPI(
    title="Anomaly Detection Service",
    version="1.0.0",
    description="Detects anomalies in renewable energy telemetry data",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Anomaly Detector ─────────────────────────────────────────────────────────

class AnomalyDetector:
    THRESHOLDS = {
        "temperature":   {"min": 20,  "max": 80,  "rate_change": 10},
        "vibration":     {"min": 0,   "max": 5,   "rate_change": 0.5},
        "power_output":  {"min": 0,   "max": 100, "rate_change": 20},
        "wind_speed":    {"min": 0,   "max": 25,  "rate_change": 5},
        "rotor_speed":   {"min": 0,   "max": 20,  "rate_change": 3},
        "solar_irr":     {"min": 0,   "max": 1200,"rate_change": 200},
        "voltage":       {"min": 200, "max": 250, "rate_change": 15},
        "current":       {"min": 0,   "max": 500, "rate_change": 50},
    }
    _models: Dict[str, IsolationForest] = {}

    RECS = {
        "temperature": {"HIGH": ["Check cooling system", "Verify ambient conditions"], "MEDIUM": ["Monitor temperature trend"]},
        "vibration":   {"HIGH": ["Immediate inspection required", "Check bearings"],    "MEDIUM": ["Schedule vibration analysis"]},
        "power_output":{"HIGH": ["Inspect power electronics", "Check grid connection"], "MEDIUM": ["Review load profile"]},
        "wind_speed":  {"HIGH": ["Check anemometer calibration"],                       "MEDIUM": ["Log for trend analysis"]},
        "rotor_speed": {"HIGH": ["Emergency brake check", "Inspect gearbox"],           "MEDIUM": ["Schedule rotor inspection"]},
    }

    def detect(self, telemetry: TelemetryData, history: List[Dict]) -> List[Anomaly]:
        anomalies: List[Anomaly] = []
        for metric, value in telemetry.metrics.items():
            threshold = self.THRESHOLDS.get(metric)
            if threshold:
                if value < threshold["min"] or value > threshold["max"]:
                    anomalies.append(self._make(telemetry, metric, value, threshold["max"], "HIGH",
                                                [f"Value {value:.2f} outside range [{threshold['min']}, {threshold['max']}]"]))
                elif history:
                    prev = [d["metrics"].get(metric) for d in history if d.get("metrics", {}).get(metric) is not None]
                    if prev and abs(value - prev[-1]) > threshold["rate_change"]:
                        anomalies.append(self._make(telemetry, metric, value, threshold["rate_change"], "MEDIUM",
                                                    [f"Rapid change detected: {abs(value - prev[-1]):.2f}"]))

            # Isolation Forest for sufficient history
            if len(history) >= 15:
                key = f"{telemetry.asset_id}:{metric}"
                if key not in self._models:
                    self._models[key] = IsolationForest(contamination=0.1, random_state=42)
                vals = np.array([[d["metrics"].get(metric, 0)] for d in history] + [[value]])
                try:
                    self._models[key].fit(vals[:-1])
                    if self._models[key].predict([[value]])[0] == -1:
                        anomalies.append(self._make(telemetry, metric, value, 0, "MEDIUM",
                                                    ["Unusual pattern detected by ML model"]))
                except Exception:
                    pass
        return anomalies

    def _make(self, t: TelemetryData, metric: str, value: float, threshold: float,
              severity: str, recs: List[str]) -> Anomaly:
        default_recs = self.RECS.get(metric, {}).get(severity, ["Monitor and investigate"])
        return Anomaly(
            asset_id=t.asset_id,
            timestamp=t.timestamp,
            metric_name=metric,
            value=value,
            threshold=threshold,
            severity=severity,
            recommendations=recs or default_recs,
        )

detector = AnomalyDetector()

# ─── Helpers ──────────────────────────────────────────────────────────────────

async def fetch_history(asset_id: str, window_min: int) -> List[Dict]:
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_TELEMETRY)
        end = datetime.now(timezone.utc)
        start = end - timedelta(minutes=window_min)
        resp = table.query(
            KeyConditionExpression="asset_id = :a AND #ts BETWEEN :s AND :e",
            ExpressionAttributeNames={"#ts": "timestamp"},
            ExpressionAttributeValues={
                ":a": asset_id,
                ":s": start.isoformat(),
                ":e": end.isoformat(),
            },
            Limit=500,
            ScanIndexForward=False,
        )
        return resp.get("Items", [])
    except Exception as exc:
        logger.warning("fetch_history failed: %s", exc)
        return []

async def store_anomalies(anomalies: List[Anomaly]):
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_ANOMALIES)
        for a in anomalies:
            table.put_item(Item={
                "anomaly_id": f"{a.asset_id}#{a.timestamp.isoformat()}#{a.metric_name}",
                "asset_id": a.asset_id,
                "timestamp": a.timestamp.isoformat(),
                "metric_name": a.metric_name,
                "value": str(a.value),
                "threshold": str(a.threshold),
                "severity": a.severity,
                "recommendations": a.recommendations,
                "detected_at": datetime.now(timezone.utc).isoformat(),
            })
    except Exception as exc:
        logger.error("store_anomalies failed: %s", exc)

async def publish_anomaly_events(anomalies: List[Anomaly]):
    if not SNS_TOPIC_ARN:
        return
    try:
        for a in anomalies:
            msg = {
                "EventType": "AnomalyDetected",
                "asset_id": a.asset_id,
                "timestamp": a.timestamp.isoformat(),
                "metric_name": a.metric_name,
                "severity": a.severity,
                "value": a.value,
                "recommendations": a.recommendations,
            }
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=json.dumps(msg),
                MessageAttributes={"EventType": {"DataType": "String", "StringValue": "AnomalyDetected"}},
            )
    except Exception as exc:
        logger.error("publish_anomaly_events failed: %s", exc)

# ─── API Endpoints ────────────────────────────────────────────────────────────

@app.post("/api/v1/detect")
async def detect_anomalies(request: AnomalyDetectionRequest):
    try:
        history = await fetch_history(request.telemetry_data.asset_id, request.historical_window_minutes)
        anomalies = detector.detect(request.telemetry_data, history)
        if anomalies:
            await store_anomalies(anomalies)
            await publish_anomaly_events(anomalies)
        return {
            "asset_id": request.telemetry_data.asset_id,
            "timestamp": request.telemetry_data.timestamp,
            "anomalies": [a.model_dump() for a in anomalies],
            "count": len(anomalies),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

@app.get("/api/v1/anomalies/{asset_id}")
async def get_anomalies(asset_id: str, limit: int = 100):
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_ANOMALIES)
        resp = table.query(
            IndexName="asset_id-index",
            KeyConditionExpression="asset_id = :a",
            ExpressionAttributeValues={":a": asset_id},
            ScanIndexForward=False,
            Limit=limit,
        )
        return {"asset_id": asset_id, "anomalies": resp.get("Items", []), "count": len(resp.get("Items", []))}
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

@app.get("/api/v1/anomalies")
async def list_all_anomalies(limit: int = 100):
    try:
        table = dynamodb.Table(DYNAMODB_TABLE_ANOMALIES)
        resp = table.scan(Limit=limit)
        items = sorted(resp.get("Items", []), key=lambda x: x.get("detected_at", ""), reverse=True)
        return {"anomalies": items, "count": len(items)}
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

# ─── Event Consumer ────────────────────────────────────────────────────────────

async def consume_telemetry_events():
    if not SQS_QUEUE_URL:
        logger.info("No SQS_QUEUE_URL set – skipping event consumer")
        return
    logger.info("Starting telemetry SQS consumer on %s", SQS_QUEUE_URL)
    while True:
        try:
            resp = sqs_client.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=5,
            )
            for msg in resp.get("Messages", []):
                try:
                    body = json.loads(msg["Body"])
                    if isinstance(body, dict) and body.get("EventType") == "TelemetryReceived":
                        td = TelemetryData(**{k: v for k, v in body.items() if k != "EventType"})
                        req = AnomalyDetectionRequest(telemetry_data=td)
                        await detect_anomalies(req)
                    sqs_client.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
                except Exception as exc:
                    logger.error("Error processing SQS message: %s", exc)
        except Exception as exc:
            logger.error("SQS consumer error: %s", exc)
            await asyncio.sleep(5)

# ─── Health ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat(), "version": "1.0.0"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
