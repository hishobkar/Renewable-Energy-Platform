"""Telemetry Service – ingests IoT telemetry, stores in DynamoDB, publishes to SQS/SNS."""
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
from pydantic import BaseModel
import json
import uuid
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─── Config ───────────────────────────────────────────────────────────────────
AWS_ENDPOINT = os.getenv("AWS_ENDPOINT_URL")
REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
TABLE_TELEMETRY = os.getenv("DYNAMODB_TABLE_TELEMETRY", "Telemetry")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL", "")
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "")

boto_kwargs: Dict[str, Any] = {"region_name": REGION}
if AWS_ENDPOINT:
    boto_kwargs["endpoint_url"] = AWS_ENDPOINT

dynamodb = boto3.resource("dynamodb", **boto_kwargs)
sqs_client = boto3.client("sqs", **boto_kwargs)
sns_client = boto3.client("sns", **boto_kwargs)

# ─── Models ──────────────────────────────────────────────────────────────────

class TelemetryDatapoint(BaseModel):
    asset_id: str
    timestamp: Optional[datetime] = None
    type: str
    metrics: Dict[str, float]
    source: str = "sensor"
    quality: float = 1.0

class BatchTelemetry(BaseModel):
    records: List[TelemetryDatapoint]

class TelemetryQuery(BaseModel):
    asset_id: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    limit: int = 100

# ─── App ──────────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Telemetry Service")
    yield
    logger.info("Shutting down Telemetry Service")

app = FastAPI(
    title="Telemetry Service",
    version="1.0.0",
    description="Ingests and queries IoT telemetry for renewable energy assets",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Core ─────────────────────────────────────────────────────────────────────

def _store_record(record: TelemetryDatapoint) -> str:
    ts = record.timestamp or datetime.now(timezone.utc)
    record_id = str(uuid.uuid4())
    table = dynamodb.Table(TABLE_TELEMETRY)
    table.put_item(Item={
        "asset_id": record.asset_id,
        "timestamp": ts.isoformat(),
        "record_id": record_id,
        "type": record.type,
        "metrics": {k: str(v) for k, v in record.metrics.items()},
        "source": record.source,
        "quality": str(record.quality),
        "ingested_at": datetime.now(timezone.utc).isoformat(),
    })
    return record_id

def _publish(record: TelemetryDatapoint):
    ts = record.timestamp or datetime.now(timezone.utc)
    msg = {
        "EventType": "TelemetryReceived",
        "asset_id": record.asset_id,
        "timestamp": ts.isoformat(),
        "type": record.type,
        "metrics": record.metrics,
        "source": record.source,
    }
    msg_str = json.dumps(msg)
    if SQS_QUEUE_URL:
        try:
            sqs_client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=msg_str,
                MessageAttributes={"EventType": {"DataType": "String", "StringValue": "TelemetryReceived"}},
            )
        except Exception as exc:
            logger.warning("SQS publish failed: %s", exc)
    if SNS_TOPIC_ARN:
        try:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=msg_str,
                MessageAttributes={"EventType": {"DataType": "String", "StringValue": "TelemetryReceived"}},
            )
        except Exception as exc:
            logger.warning("SNS publish failed: %s", exc)

# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.post("/api/v1/telemetry", status_code=201)
async def ingest_telemetry(record: TelemetryDatapoint, background: BackgroundTasks):
    try:
        record_id = _store_record(record)
        background.add_task(_publish, record)
        return {"record_id": record_id, "status": "accepted", "asset_id": record.asset_id}
    except Exception as exc:
        logger.error("Ingest failed: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))

@app.post("/api/v1/telemetry/batch", status_code=201)
async def ingest_batch(batch: BatchTelemetry, background: BackgroundTasks):
    ids = []
    for record in batch.records:
        try:
            rid = _store_record(record)
            ids.append(rid)
            background.add_task(_publish, record)
        except Exception as exc:
            logger.error("Batch record failed: %s", exc)
    return {"accepted": len(ids), "record_ids": ids}

@app.get("/api/v1/telemetry/{asset_id}")
async def get_telemetry(
    asset_id: str,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    limit: int = 100,
):
    try:
        table = dynamodb.Table(TABLE_TELEMETRY)
        end = end_time or datetime.now(timezone.utc).isoformat()
        start = start_time or (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()

        resp = table.query(
            KeyConditionExpression="asset_id = :a AND #ts BETWEEN :s AND :e",
            ExpressionAttributeNames={"#ts": "timestamp"},
            ExpressionAttributeValues={":a": asset_id, ":s": start, ":e": end},
            Limit=limit,
            ScanIndexForward=False,
        )
        items = resp.get("Items", [])
        # Convert string metrics back to float
        for item in items:
            if isinstance(item.get("metrics"), dict):
                item["metrics"] = {k: float(v) for k, v in item["metrics"].items()}
        return {"asset_id": asset_id, "records": items, "count": len(items)}
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

@app.get("/api/v1/telemetry/{asset_id}/latest")
async def get_latest_telemetry(asset_id: str):
    try:
        table = dynamodb.Table(TABLE_TELEMETRY)
        resp = table.query(
            KeyConditionExpression="asset_id = :a",
            ExpressionAttributeValues={":a": asset_id},
            Limit=1,
            ScanIndexForward=False,
        )
        items = resp.get("Items", [])
        if not items:
            return {"asset_id": asset_id, "record": None}
        item = items[0]
        if isinstance(item.get("metrics"), dict):
            item["metrics"] = {k: float(v) for k, v in item["metrics"].items()}
        return {"asset_id": asset_id, "record": item}
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

@app.get("/api/v1/telemetry")
async def list_recent_telemetry(limit: int = 200):
    """Scan all recent telemetry (demo endpoint)."""
    try:
        table = dynamodb.Table(TABLE_TELEMETRY)
        resp = table.scan(Limit=limit)
        items = sorted(resp.get("Items", []), key=lambda x: x.get("timestamp", ""), reverse=True)
        for item in items:
            if isinstance(item.get("metrics"), dict):
                item["metrics"] = {k: float(v) for k, v in item["metrics"].items()}
        return {"records": items, "count": len(items)}
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

# ─── Health ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat(), "version": "1.0.0"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
