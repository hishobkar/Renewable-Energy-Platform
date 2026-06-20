#!/usr/bin/env bash
# deploy-staging.sh — Deploy all services to the staging ECS cluster.
# First runs smoke tests on dev to ensure dev is healthy before promoting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER="${ECS_CLUSTER_STAGING:-renewable-energy-staging}"
AWS_REGION="${AWS_REGION:-us-east-1}"

SERVICES=(
  "asset-service"
  "telemetry-service"
  "anomaly-detection-service"
  "alert-service"
  "simulator"
  "dashboard"
)

STABLE_WAIT_TIMEOUT=600

echo "========================================"
echo " Deploy to Staging — $CLUSTER"
echo "========================================"
echo "Region  : $AWS_REGION"
echo "Cluster : $CLUSTER"
echo "----------------------------------------"

# Step 0: Run smoke tests on dev before promoting
echo "=== Step 0: Smoke testing dev before promoting to staging ==="
echo ""
if [ -f "$SCRIPT_DIR/smoke-test.sh" ]; then
  echo "Running smoke tests on dev..."
  if bash "$SCRIPT_DIR/smoke-test.sh" dev; then
    echo "[OK] Dev smoke tests passed. Proceeding with staging deployment."
  else
    echo "[FAIL] Dev smoke tests FAILED. Aborting staging deployment."
    echo "       Fix issues in dev before promoting to staging."
    exit 1
  fi
else
  echo "WARNING: smoke-test.sh not found at $SCRIPT_DIR/smoke-test.sh"
  echo "         Skipping pre-promotion dev smoke test."
fi

echo ""
echo "=== Step 1: Verifying staging cluster ==="
CLUSTER_STATUS=$(aws ecs describe-clusters \
  --clusters "$CLUSTER" \
  --region "$AWS_REGION" \
  --query 'clusters[0].status' \
  --output text 2>/dev/null || echo "NONE")

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
  echo "ERROR: Staging cluster '$CLUSTER' not found or not ACTIVE (status: $CLUSTER_STATUS)"
  exit 1
fi
echo "Staging cluster '$CLUSTER' is ACTIVE."

DEPLOY_ERRORS=()
TOTAL_START=$(date +%s)

# Step 2: Trigger deployments
echo ""
echo "=== Step 2: Triggering staging deployments ==="
for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "Deploying $SERVICE to staging..."
  RESULT=$(aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --force-new-deployment \
    --region "$AWS_REGION" \
    --query 'service.{name:serviceName,desiredCount:desiredCount,runningCount:runningCount}' \
    --output json 2>&1) || {
    echo "  ERROR: Failed to deploy $SERVICE to staging"
    DEPLOY_ERRORS+=("$SERVICE: update-service failed")
    continue
  }

  DESIRED=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('desiredCount','?'))" 2>/dev/null || echo "?")
  RUNNING=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('runningCount','?'))" 2>/dev/null || echo "?")
  echo "  Deployment triggered. desired=$DESIRED, running=$RUNNING"
done

# Step 3: Wait for stabilization
echo ""
echo "=== Step 3: Waiting for staging services to stabilize ==="
for SERVICE in "${SERVICES[@]}"; do
  SKIP=false
  for ERR in "${DEPLOY_ERRORS[@]}"; do
    [[ "$ERR" == "$SERVICE:"* ]] && SKIP=true && break
  done
  [ "$SKIP" = "true" ] && { echo "Skipping wait for $SERVICE"; continue; }

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
    echo "  [FAIL] $SERVICE did not stabilize"
    DEPLOY_ERRORS+=("$SERVICE: wait timed out")
  fi
done

TOTAL_END=$(date +%s)

# Step 4: Print final status
echo ""
echo "=== Step 4: Final staging service status ==="
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
echo " Staging Deployment Summary"
echo "========================================"
echo "Total time: $((TOTAL_END - TOTAL_START))s"

if [ ${#DEPLOY_ERRORS[@]} -eq 0 ]; then
  echo "Status: ALL SERVICES DEPLOYED TO STAGING SUCCESSFULLY"
  echo ""
  echo "Run staging smoke tests:"
  echo "  ./smoke-test.sh staging"
  exit 0
else
  echo "Status: STAGING DEPLOYMENT FAILED"
  for ERR in "${DEPLOY_ERRORS[@]}"; do
    echo "  - $ERR"
  done
  exit 1
fi
