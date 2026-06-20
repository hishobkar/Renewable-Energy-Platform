#!/bin/sh
# Initialise LocalStack with all required AWS resources

ENDPOINT=http://localstack:4566
REGION=us-east-1

echo "==> Waiting for LocalStack to be fully ready..."
until curl -sf "$ENDPOINT/_localstack/health" > /dev/null 2>&1; do
  echo "    LocalStack not yet ready, retrying..."
  sleep 3
done
# Give services a moment to initialise after HTTP is up
sleep 5
echo "    LocalStack is ready."

# ─── DynamoDB Tables ──────────────────────────────────────────────────────────
echo "==> Creating DynamoDB tables..."

aws --endpoint-url="$ENDPOINT" dynamodb create-table \
  --table-name Telemetry \
  --attribute-definitions AttributeName=asset_id,AttributeType=S AttributeName=timestamp,AttributeType=S \
  --key-schema AttributeName=asset_id,KeyType=HASH AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION 2>/dev/null || echo "    Telemetry table already exists."

aws --endpoint-url="$ENDPOINT" dynamodb create-table \
  --table-name Anomalies \
  --attribute-definitions AttributeName=anomaly_id,AttributeType=S AttributeName=asset_id,AttributeType=S \
  --key-schema AttributeName=anomaly_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes '[{"IndexName":"asset_id-index","KeySchema":[{"AttributeName":"asset_id","KeyType":"HASH"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --region $REGION 2>/dev/null || echo "    Anomalies table already exists."

aws --endpoint-url="$ENDPOINT" dynamodb create-table \
  --table-name Alerts \
  --attribute-definitions AttributeName=alert_id,AttributeType=S AttributeName=asset_id,AttributeType=S AttributeName=metric_name,AttributeType=S \
  --key-schema AttributeName=alert_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes '[{"IndexName":"asset_id-metric_name-index","KeySchema":[{"AttributeName":"asset_id","KeyType":"HASH"},{"AttributeName":"metric_name","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --region $REGION 2>/dev/null || echo "    Alerts table already exists."

# ─── SQS Queues ───────────────────────────────────────────────────────────────
echo "==> Creating SQS queues..."

aws --endpoint-url="$ENDPOINT" sqs create-queue \
  --queue-name telemetry-events \
  --region $REGION 2>/dev/null || echo "    telemetry-events queue already exists."

aws --endpoint-url="$ENDPOINT" sqs create-queue \
  --queue-name anomaly-events \
  --region $REGION 2>/dev/null || echo "    anomaly-events queue already exists."

aws --endpoint-url="$ENDPOINT" sqs create-queue \
  --queue-name alert-events \
  --region $REGION 2>/dev/null || echo "    alert-events queue already exists."

# ─── SNS Topics ───────────────────────────────────────────────────────────────
echo "==> Creating SNS topics..."

aws --endpoint-url="$ENDPOINT" sns create-topic \
  --name telemetry-topic \
  --region $REGION 2>/dev/null || echo "    telemetry-topic already exists."

aws --endpoint-url="$ENDPOINT" sns create-topic \
  --name anomaly-topic \
  --region $REGION 2>/dev/null || echo "    anomaly-topic already exists."

aws --endpoint-url="$ENDPOINT" sns create-topic \
  --name alert-topic \
  --region $REGION 2>/dev/null || echo "    alert-topic already exists."

# ─── SNS → SQS Subscriptions ──────────────────────────────────────────────────
echo "==> Subscribing SQS queues to SNS topics..."

ANOMALY_TOPIC_ARN="arn:aws:sns:$REGION:000000000000:anomaly-topic"
ANOMALY_QUEUE_URL="$ENDPOINT/000000000000/anomaly-events"
ANOMALY_QUEUE_ARN="arn:aws:sqs:$REGION:000000000000:anomaly-events"

aws --endpoint-url="$ENDPOINT" sns subscribe \
  --topic-arn "$ANOMALY_TOPIC_ARN" \
  --protocol sqs \
  --notification-endpoint "$ANOMALY_QUEUE_ARN" \
  --region $REGION 2>/dev/null || echo "    Subscription already exists."

echo "==> AWS resources initialised successfully."
