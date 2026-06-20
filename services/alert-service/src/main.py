"""Alert Service – creates and dispatches alerts for renewable energy anomalies."""
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
import logging
import os
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
import boto3
from botocore.exceptions import ClientError
from pydantic import BaseModel
import json
import asyncio
from enum import Enum
import uuid

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─── Config ───────────────────────────────────────────────────────────────────
AWS_ENDPOINT = os.getenv("AWS_ENDPOINT_URL")
REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
TABLE_ALERTS = os.getenv("DYNAMODB_TABLE_ALERTS", "Alerts")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL", "")
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "")

boto_kwargs: Dict[str, Any] = {"region_name": REGION}
if AWS_ENDPOINT:
    boto_kwargs["endpoint_url"] = AWS_ENDPOINT

dynamodb = boto3.resource("dynamodb", **boto_kwargs)
sqs_client = boto3.client("sqs", **boto_kwargs)
sns_client = boto3.client("sns", **boto_kwargs)

# ─── Models ──────────────────────────────────────────────────────────────────

class AlertSeverity(str, Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"

class AlertStatus(str, Enum):
    NEW = "NEW"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    RESOLVED = "RESOLVED"
    IGNORED = "IGNORED"

class AlertChannel(str, Enum):
    EMAIL = "EMAIL"
    SMS = "SMS"
    SLACK = "SLACK"
    PAGERDUTY = "PAGERDUTY"
    WEBHOOK = "WEBHOOK"

class AlertRequest(BaseModel):
    asset_id: str
    timestamp: datetime
    metric_name: str
    value: float
    threshold: float
    severity: AlertSeverity
    recommendations: List[str] = []
    source: str = "anomaly-detection"

class Alert(BaseModel):
    id: str
    asset_id: str
    timestamp: datetime
    metric_name: str
    value: float
    threshold: float
    severity: AlertSeverity
    status: AlertStatus
    recommendations: List[str]
    notified_channels: List[str]
    created_at: datetime
    acknowledged_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None
    notes: List[str] = []

# ─── App ──────────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Alert Service")
    asyncio.create_task(consume_anomaly_events())
    yield
    logger.info("Shutting down Alert Service")

app = FastAPI(
    title="Alert Service",
    version="1.0.0",
    description="Manages and dispatches alerts for renewable energy anomalies",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Repository ──────────────────────────────────────────────────────────────

def _alerts_table():
    return dynamodb.Table(TABLE_ALERTS)

def _save_alert(alert: Alert):
    _alerts_table().put_item(Item={
        "alert_id": alert.id,
        "asset_id": alert.asset_id,
        "timestamp": alert.timestamp.isoformat(),
        "metric_name": alert.metric_name,
        "value": str(alert.value),
        "threshold": str(alert.threshold),
        "severity": alert.severity.value,
        "status": alert.status.value,
        "recommendations": alert.recommendations,
        "notified_channels": alert.notified_channels,
        "created_at": alert.created_at.isoformat(),
        "acknowledged_at": alert.acknowledged_at.isoformat() if alert.acknowledged_at else None,
        "resolved_at": alert.resolved_at.isoformat() if alert.resolved_at else None,
        "notes": alert.notes,
    })

# ─── Notification ─────────────────────────────────────────────────────────────

def _notify(alert: Alert) -> List[str]:
    """Log-based notifications (real email/SMS/Slack would call external APIs)."""
    channels = []
    severity = alert.severity
    logger.info(
        "[ALERT][%s] asset=%s metric=%s value=%s recs=%s",
        severity.value, alert.asset_id, alert.metric_name, alert.value, alert.recommendations,
    )
    channels.append(AlertChannel.WEBHOOK.value)
    if severity in (AlertSeverity.HIGH, AlertSeverity.CRITICAL):
        logger.warning("[SLACK] Would post to #ops channel: %s on %s", alert.metric_name, alert.asset_id)
        channels.append(AlertChannel.SLACK.value)
    if severity == AlertSeverity.CRITICAL:
        logger.critical("[PAGERDUTY] Would page on-call: %s on %s", alert.metric_name, alert.asset_id)
        channels.append(AlertChannel.PAGERDUTY.value)
    return channels

# ─── Alert creation ────────────────────────────────────────────────────────────

async def create_alert_from_data(data: Dict) -> Alert:
    alert = Alert(
        id=str(uuid.uuid4()),
        asset_id=data["asset_id"],
        timestamp=datetime.fromisoformat(data["timestamp"]) if isinstance(data["timestamp"], str) else data["timestamp"],
        metric_name=data["metric_name"],
        value=float(data["value"]),
        threshold=float(data.get("threshold", 0)),
        severity=AlertSeverity(data["severity"]),
        status=AlertStatus.NEW,
        recommendations=data.get("recommendations", []),
        notified_channels=[],
        created_at=datetime.now(timezone.utc),
    )
    try:
        channels = _notify(alert)
        alert.notified_channels = channels
        _save_alert(alert)
        logger.info("Alert %s created for asset %s", alert.id, alert.asset_id)
    except Exception as exc:
        logger.error("Failed to create alert: %s", exc)
    return alert

# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.post("/api/v1/alerts", status_code=201)
async def create_alert(req: AlertRequest):
    return await create_alert_from_data(req.model_dump())

@app.get("/api/v1/alerts")
async def list_alerts(
    asset_id: Optional[str] = None,
    severity: Optional[AlertSeverity] = None,
    status: Optional[AlertStatus] = None,
    limit: int = 100,
):
    try:
        table = _alerts_table()
        resp = table.scan(Limit=limit)
        items = resp.get("Items", [])
        if asset_id:
            items = [i for i in items if i.get("asset_id") == asset_id]
        if severity:
            items = [i for i in items if i.get("severity") == severity.value]
        if status:
            items = [i for i in items if i.get("status") == status.value]
        items = sorted(items, key=lambda x: x.get("created_at", ""), reverse=True)
        return {"alerts": items, "count": len(items)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

@app.get("/api/v1/alerts/{alert_id}")
async def get_alert(alert_id: str):
    try:
        resp = _alerts_table().get_item(Key={"alert_id": alert_id})
        item = resp.get("Item")
        if not item:
            raise HTTPException(status_code=404, detail="Alert not found")
        return item
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

@app.put("/api/v1/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(alert_id: str):
    try:
        resp = _alerts_table().update_item(
            Key={"alert_id": alert_id},
            UpdateExpression="SET #s = :s, acknowledged_at = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": AlertStatus.ACKNOWLEDGED.value, ":t": datetime.now(timezone.utc).isoformat()},
            ReturnValues="ALL_NEW",
        )
        return resp.get("Attributes", {})
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

@app.put("/api/v1/alerts/{alert_id}/resolve")
async def resolve_alert(alert_id: str):
    try:
        resp = _alerts_table().update_item(
            Key={"alert_id": alert_id},
            UpdateExpression="SET #s = :s, resolved_at = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": AlertStatus.RESOLVED.value, ":t": datetime.now(timezone.utc).isoformat()},
            ReturnValues="ALL_NEW",
        )
        return resp.get("Attributes", {})
    except ClientError as exc:
        raise HTTPException(status_code=500, detail=str(exc))

# ─── SQS Consumer ─────────────────────────────────────────────────────────────

async def consume_anomaly_events():
    if not SQS_QUEUE_URL:
        logger.info("No SQS_QUEUE_URL set – skipping event consumer")
        return
    logger.info("Starting anomaly SQS consumer on %s", SQS_QUEUE_URL)
    while True:
        try:
            resp = sqs_client.receive_message(QueueUrl=SQS_QUEUE_URL, MaxNumberOfMessages=10, WaitTimeSeconds=5)
            for msg in resp.get("Messages", []):
                try:
                    body = json.loads(msg["Body"])
                    # SNS wraps messages in another JSON envelope
                    if "Message" in body:
                        body = json.loads(body["Message"])
                    if body.get("EventType") == "AnomalyDetected":
                        await create_alert_from_data(body)
                    sqs_client.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
                except Exception as exc:
                    logger.error("Error processing message: %s", exc)
        except Exception as exc:
            logger.error("SQS consumer error: %s", exc)
            await asyncio.sleep(5)

# ─── Health ────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat(), "version": "1.0.0"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
