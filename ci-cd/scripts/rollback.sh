#!/usr/bin/env bash
# rollback.sh — Roll back ECS services to the previous task definition revision.
# Usage: ./rollback.sh [ENVIRONMENT] [PREVIOUS_TASK_DEF_ARN]
#
# If PREVIOUS_TASK_DEF_ARN is not provided, rolls back each service to
# the immediately preceding task definition revision.
# Sends an SNS notification on rollback completion.

set -euo pipefail

ENVIRONMENT="${1:-dev}"
PREVIOUS_TASK_DEF_ARN="${2:-}"

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo '')}"
SNS_TOPIC_ARN="${SNS_TOPIC_ARN:-arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:renewable-energy-${ENVIRONMENT}-pipeline-notifications}"

case "$ENVIRONMENT" in
  dev)
    CLUSTER="${ECS_CLUSTER_DEV:-renewable-energy-dev}"
    ;;
  staging)
    CLUSTER="${ECS_CLUSTER_STAGING:-renewable-energy-staging}"
    ;;
  prod)
    CLUSTER="${ECS_CLUSTER_PROD:-renewable-energy-prod}"
    ;;
  *)
    echo "ERROR: Unknown environment '$ENVIRONMENT'. Must be dev, staging, or prod."
    exit 1
    ;;
esac

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
echo " Rollback — $ENVIRONMENT ($CLUSTER)"
echo "========================================"
echo "Environment          : $ENVIRONMENT"
echo "Cluster              : $CLUSTER"
echo "Region               : $AWS_REGION"
echo "Previous Task Def ARN: ${PREVIOUS_TASK_DEF_ARN:-auto-detect (rev - 1)}"
echo "----------------------------------------"

# Safety confirmation for production
if [ "$ENVIRONMENT" = "prod" ]; then
  if [ -z "${ROLLBACK_CONFIRMED:-}" ]; then
    echo ""
    echo "WARNING: You are about to roll back PRODUCTION services."
    echo "Set ROLLBACK_CONFIRMED=yes to skip this prompt."
    read -r -p "Type 'yes' to confirm production rollback: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Rollback aborted."
      exit 0
    fi
  fi
fi

ROLLBACK_ERRORS=()
ROLLBACK_RESULTS=()
TOTAL_START=$(date +%s)

# Step 1: Update each service to the previous task definition
echo ""
echo "=== Step 1: Updating services to previous task definitions ==="
for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "Rolling back $SERVICE..."

  if [ -n "$PREVIOUS_TASK_DEF_ARN" ]; then
    TARGET_TASK_DEF="$PREVIOUS_TASK_DEF_ARN"
    echo "  Using provided task def: $TARGET_TASK_DEF"
  else
    # Auto-detect: get current task def and decrement revision
    CURRENT_TASK_DEF=$(aws ecs describe-services \
      --cluster "$CLUSTER" \
      --services "$SERVICE" \
      --region "$AWS_REGION" \
      --query 'services[0].taskDefinition' \
      --output text 2>/dev/null || echo "")

    if [ -z "$CURRENT_TASK_DEF" ] || [ "$CURRENT_TASK_DEF" = "None" ]; then
      echo "  WARNING: Service $SERVICE not found in cluster $CLUSTER, skipping."
      ROLLBACK_ERRORS+=("$SERVICE: not found in cluster")
      continue
    fi

    echo "  Current task def: $CURRENT_TASK_DEF"

    # Parse ARN: arn:aws:ecs:region:account:task-definition/family:revision
    FAMILY=$(echo "$CURRENT_TASK_DEF" | sed 's|.*/||' | cut -d: -f1)
    CURRENT_REV=$(echo "$CURRENT_TASK_DEF" | sed 's|.*:||')

    if [ "$CURRENT_REV" -le 1 ]; then
      echo "  WARNING: $SERVICE is at revision 1, cannot roll back further."
      ROLLBACK_ERRORS+=("$SERVICE: already at revision 1")
      continue
    fi

    PREV_REV=$((CURRENT_REV - 1))
    TARGET_TASK_DEF="${FAMILY}:${PREV_REV}"
    echo "  Rolling back from rev $CURRENT_REV to $PREV_REV"
  fi

  # Verify the target task definition exists
  TARGET_TASK_DEF_ARN=$(aws ecs describe-task-definition \
    --task-definition "$TARGET_TASK_DEF" \
    --region "$AWS_REGION" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text 2>/dev/null || echo "")

  if [ -z "$TARGET_TASK_DEF_ARN" ] || [ "$TARGET_TASK_DEF_ARN" = "None" ]; then
    echo "  ERROR: Target task definition '$TARGET_TASK_DEF' not found."
    ROLLBACK_ERRORS+=("$SERVICE: target task def not found ($TARGET_TASK_DEF)")
    continue
  fi

  # Update the service
  if aws ecs update-service \
      --cluster "$CLUSTER" \
      --service "$SERVICE" \
      --task-definition "$TARGET_TASK_DEF_ARN" \
      --force-new-deployment \
      --region "$AWS_REGION" \
      --output text > /dev/null; then
    echo "  Rollback initiated: $TARGET_TASK_DEF_ARN"
    ROLLBACK_RESULTS+=("$SERVICE rolled back to $TARGET_TASK_DEF_ARN")
  else
    echo "  ERROR: Failed to update service $SERVICE"
    ROLLBACK_ERRORS+=("$SERVICE: update-service failed")
  fi
done

# Step 2: Wait for services to stabilize
echo ""
echo "=== Step 2: Waiting for rolled-back services to stabilize ==="
for SERVICE in "${SERVICES[@]}"; do
  SKIP=false
  for ERR in "${ROLLBACK_ERRORS[@]}"; do
    [[ "$ERR" == "$SERVICE:"* ]] && SKIP=true && break
  done
  [ "$SKIP" = "true" ] && continue

  echo "Waiting for $SERVICE to stabilize..."
  SVC_START=$(date +%s)
  if aws ecs wait services-stable \
      --cluster "$CLUSTER" \
      --services "$SERVICE" \
      --region "$AWS_REGION" 2>/dev/null; then
    SVC_END=$(date +%s)
    echo "  [OK] $SERVICE stabilized in $((SVC_END - SVC_START))s"
  else
    SVC_END=$(date +%s)
    echo "  [WARN] $SERVICE did not stabilize within $((SVC_END - SVC_START))s"
    ROLLBACK_ERRORS+=("$SERVICE: stabilization timeout")
  fi
done

TOTAL_END=$(date +%s)

# Step 3: Send SNS notification about rollback
echo ""
echo "=== Step 3: Sending rollback notification ==="
RESULTS_TEXT=$(printf '%s\n' "${ROLLBACK_RESULTS[@]}" | sed 's/^/  /')
ERRORS_TEXT=$(printf '%s\n' "${ROLLBACK_ERRORS[@]:-none}" | sed 's/^/  /')

NOTIFICATION_MESSAGE="ROLLBACK NOTIFICATION
Environment : $ENVIRONMENT
Cluster     : $CLUSTER
Region      : $AWS_REGION
Time        : $(date -u +%Y-%m-%dT%H:%M:%SZ)
Duration    : $((TOTAL_END - TOTAL_START))s

Rollback Results:
$RESULTS_TEXT

Errors:
$ERRORS_TEXT

Please verify service health and investigate root cause."

SNS_RESULT=$(aws sns publish \
  --topic-arn "$SNS_TOPIC_ARN" \
  --subject "[ALERT] Rollback executed in $ENVIRONMENT" \
  --message "$NOTIFICATION_MESSAGE" \
  --region "$AWS_REGION" \
  --output text 2>/dev/null || echo "SNS_FAILED")

if [ "$SNS_RESULT" != "SNS_FAILED" ]; then
  echo "Rollback notification sent to: $SNS_TOPIC_ARN"
else
  echo "WARNING: Failed to send SNS notification (topic may not exist)"
fi

# Step 4: Print summary
echo ""
echo "========================================"
echo " Rollback Summary — $ENVIRONMENT"
echo "========================================"
echo "Total time: $((TOTAL_END - TOTAL_START))s"
echo ""
echo "Results:"
for R in "${ROLLBACK_RESULTS[@]}"; do
  echo "  [OK] $R"
done

if [ ${#ROLLBACK_ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "Errors:"
  for ERR in "${ROLLBACK_ERRORS[@]}"; do
    echo "  [FAIL] $ERR"
  done
  echo ""
  echo "ROLLBACK COMPLETED WITH ERRORS"
  exit 1
else
  echo ""
  echo "ROLLBACK COMPLETED SUCCESSFULLY"
  exit 0
fi
