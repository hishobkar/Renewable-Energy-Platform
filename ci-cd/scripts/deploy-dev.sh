#!/usr/bin/env bash
# deploy-dev.sh — Deploy all services to the dev ECS cluster.
# Performs force-new-deployment for each service and waits for stability.

set -euo pipefail

CLUSTER="${ECS_CLUSTER_DEV:-renewable-energy-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

SERVICES=(
  "asset-service"
  "telemetry-service"
  "anomaly-detection-service"
  "alert-service"
  "simulator"
  "dashboard"
)

STABLE_WAIT_TIMEOUT=600   # 10 minutes per service

echo "========================================"
echo " Deploy to Dev — $CLUSTER"
echo "========================================"
echo "Region  : $AWS_REGION"
echo "Cluster : $CLUSTER"
echo "Services: ${#SERVICES[@]}"
echo "----------------------------------------"

# Verify cluster exists
echo "Verifying cluster '$CLUSTER' exists..."
CLUSTER_STATUS=$(aws ecs describe-clusters \
  --clusters "$CLUSTER" \
  --region "$AWS_REGION" \
  --query 'clusters[0].status' \
  --output text 2>/dev/null || echo "NONE")

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
  echo "ERROR: Cluster '$CLUSTER' not found or not ACTIVE (status: $CLUSTER_STATUS)"
  exit 1
fi
echo "Cluster '$CLUSTER' is ACTIVE."
echo ""

DEPLOY_ERRORS=()
TOTAL_START=$(date +%s)

# Step 1: Trigger deployments for all services
echo "=== Step 1: Triggering deployments ==="
for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "Deploying $SERVICE..."
  RESULT=$(aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --force-new-deployment \
    --region "$AWS_REGION" \
    --query 'service.{name:serviceName,desiredCount:desiredCount,runningCount:runningCount,pendingCount:pendingCount}' \
    --output json 2>&1) || {
    echo "  ERROR: Failed to trigger deployment for $SERVICE"
    DEPLOY_ERRORS+=("$SERVICE: update-service failed")
    continue
  }

  DESIRED=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('desiredCount','?'))" 2>/dev/null || echo "?")
  RUNNING=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('runningCount','?'))" 2>/dev/null || echo "?")
  echo "  Deployment triggered. desired=$DESIRED, running=$RUNNING"
done

# Step 2: Wait for each service to stabilize
echo ""
echo "=== Step 2: Waiting for services to stabilize (timeout: ${STABLE_WAIT_TIMEOUT}s each) ==="
for SERVICE in "${SERVICES[@]}"; do
  # Skip if this service already failed to update
  SKIP=false
  for ERR in "${DEPLOY_ERRORS[@]}"; do
    if [[ "$ERR" == "$SERVICE:"* ]]; then
      SKIP=true
      break
    fi
  done
  if [ "$SKIP" = "true" ]; then
    echo "Skipping wait for $SERVICE (deployment failed)"
    continue
  fi

  echo ""
  echo "Waiting for $SERVICE to stabilize..."
  SVC_START=$(date +%s)

  if aws ecs wait services-stable \
      --cluster "$CLUSTER" \
      --services "$SERVICE" \
      --region "$AWS_REGION"; then
    SVC_END=$(date +%s)
    echo "  [OK] $SERVICE stabilized in $((SVC_END - SVC_START))s"
  else
    SVC_END=$(date +%s)
    echo "  [FAIL] $SERVICE did not stabilize within $((SVC_END - SVC_START))s"
    DEPLOY_ERRORS+=("$SERVICE: wait timed out")
  fi
done

TOTAL_END=$(date +%s)

# Step 3: Print final status
echo ""
echo "=== Step 3: Final service status ==="
echo ""
printf "%-35s %-10s %-10s %-10s %-15s\n" "SERVICE" "DESIRED" "RUNNING" "PENDING" "STATUS"
printf "%-35s %-10s %-10s %-10s %-15s\n" "-------" "-------" "-------" "-------" "------"

for SERVICE in "${SERVICES[@]}"; do
  SVC_JSON=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$AWS_REGION" \
    --query 'services[0].{status:status,desired:desiredCount,running:runningCount,pending:pendingCount}' \
    --output json 2>/dev/null || echo '{}')

  STATUS=$(echo "$SVC_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','N/A'))" 2>/dev/null || echo "N/A")
  DESIRED=$(echo "$SVC_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('desired','N/A'))" 2>/dev/null || echo "N/A")
  RUNNING=$(echo "$SVC_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('running','N/A'))" 2>/dev/null || echo "N/A")
  PENDING=$(echo "$SVC_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('pending','N/A'))" 2>/dev/null || echo "N/A")

  printf "%-35s %-10s %-10s %-10s %-15s\n" "$SERVICE" "$DESIRED" "$RUNNING" "$PENDING" "$STATUS"
done

echo ""
echo "========================================"
echo " Deployment Summary"
echo "========================================"
echo "Total time: $((TOTAL_END - TOTAL_START))s"

if [ ${#DEPLOY_ERRORS[@]} -eq 0 ]; then
  echo "Status: ALL SERVICES DEPLOYED SUCCESSFULLY"
  exit 0
else
  echo "Status: DEPLOYMENT FAILED"
  echo ""
  echo "Errors:"
  for ERR in "${DEPLOY_ERRORS[@]}"; do
    echo "  - $ERR"
  done
  exit 1
fi
