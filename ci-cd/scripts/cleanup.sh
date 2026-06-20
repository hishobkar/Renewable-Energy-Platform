#!/usr/bin/env bash
# cleanup.sh — Clean up old ECS task definitions, untagged ECR images,
#              old CloudWatch log streams, and CodePipeline S3 artifacts.
# Usage: ./cleanup.sh [ENVIRONMENT]
# Asks for confirmation before destructive operations.

set -euo pipefail

ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
KEEP_TASK_DEF_REVISIONS=3      # Keep last N task definition revisions per service
LOG_STREAM_RETENTION_DAYS=30   # Delete CloudWatch log streams older than N days
DRY_RUN="${DRY_RUN:-false}"     # Set DRY_RUN=true to preview without deleting

case "$ENVIRONMENT" in
  dev)
    CLUSTER="${ECS_CLUSTER_DEV:-renewable-energy-dev}"
    ARTIFACT_BUCKET="${ARTIFACT_BUCKET:-renewable-energy-pipeline-artifacts-dev}"
    DELETE_BUCKET="${DELETE_BUCKET:-false}"
    ;;
  staging)
    CLUSTER="${ECS_CLUSTER_STAGING:-renewable-energy-staging}"
    ARTIFACT_BUCKET="${ARTIFACT_BUCKET:-renewable-energy-pipeline-artifacts-staging}"
    DELETE_BUCKET="${DELETE_BUCKET:-false}"
    ;;
  prod)
    CLUSTER="${ECS_CLUSTER_PROD:-renewable-energy-prod}"
    ARTIFACT_BUCKET="${ARTIFACT_BUCKET:-renewable-energy-pipeline-artifacts-prod}"
    DELETE_BUCKET="${DELETE_BUCKET:-false}"
    ;;
  *)
    echo "ERROR: Unknown environment '$ENVIRONMENT'. Must be dev, staging, or prod."
    exit 1
    ;;
esac

ECR_PREFIX="renewable-energy"
ECR_IMAGES=(
  "$ECR_PREFIX/asset-service"
  "$ECR_PREFIX/telemetry-service"
  "$ECR_PREFIX/anomaly-detection-service"
  "$ECR_PREFIX/alert-service"
  "$ECR_PREFIX/simulator"
  "$ECR_PREFIX/dashboard"
)

ECS_SERVICES=(
  "asset-service"
  "telemetry-service"
  "anomaly-detection-service"
  "alert-service"
  "simulator"
  "dashboard"
)

echo "========================================"
echo " Cleanup — $ENVIRONMENT"
echo "========================================"
echo "Cluster   : $CLUSTER"
echo "Region    : $AWS_REGION"
echo "Dry Run   : $DRY_RUN"
echo "----------------------------------------"

# ─── Helper: confirm before destructive action ────────────────────────────
confirm() {
  local MESSAGE="$1"
  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY RUN] Would: $MESSAGE"
    return 1  # return 1 to skip the actual operation
  fi
  if [ -z "${CLEANUP_AUTO_CONFIRM:-}" ]; then
    echo ""
    echo "ACTION: $MESSAGE"
    read -r -p "Confirm? (yes/no): " REPLY
    if [ "$REPLY" != "yes" ]; then
      echo "Skipped."
      return 1
    fi
  fi
  return 0
}

TOTAL_FREED=0
ACTIONS_TAKEN=()

# ─── Step 1: Stop ECS services (set desired count to 0) ──────────────────
echo ""
echo "=== Step 1: ECS Service Management ==="
echo ""
echo "Current ECS service status in cluster $CLUSTER:"
printf "%-35s %-10s %-10s\n" "SERVICE" "DESIRED" "RUNNING"
printf "%-35s %-10s %-10s\n" "-------" "-------" "-------"

for SERVICE in "${ECS_SERVICES[@]}"; do
  SVC_INFO=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$AWS_REGION" \
    --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
    --output json 2>/dev/null || echo '{}')

  DESIRED=$(echo "$SVC_INFO" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('desired','N/A'))" 2>/dev/null || echo "N/A")
  RUNNING=$(echo "$SVC_INFO" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('running','N/A'))" 2>/dev/null || echo "N/A")
  STATUS=$(echo "$SVC_INFO" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','N/A'))" 2>/dev/null || echo "N/A")
  printf "%-35s %-10s %-10s (%s)\n" "$SERVICE" "$DESIRED" "$RUNNING" "$STATUS"
done

echo ""
if confirm "Set desired count to 0 for all ECS services in '$CLUSTER'?"; then
  for SERVICE in "${ECS_SERVICES[@]}"; do
    echo "Setting $SERVICE desired count to 0..."
    aws ecs update-service \
      --cluster "$CLUSTER" \
      --service "$SERVICE" \
      --desired-count 0 \
      --region "$AWS_REGION" \
      --output text > /dev/null 2>&1 || echo "  WARNING: Could not update $SERVICE (may not exist)"
    echo "  $SERVICE stopped."
    ACTIONS_TAKEN+=("ECS: $SERVICE set to 0 replicas")
  done
fi

# ─── Step 2: Deregister old task definition revisions ────────────────────
echo ""
echo "=== Step 2: Cleaning up old task definition revisions (keep last $KEEP_TASK_DEF_REVISIONS) ==="
for SERVICE in "${ECS_SERVICES[@]}"; do
  echo ""
  echo "Checking task definitions for $SERVICE..."

  TASK_DEF_ARNS=$(aws ecs list-task-definitions \
    --family-prefix "$SERVICE" \
    --status ACTIVE \
    --sort DESC \
    --region "$AWS_REGION" \
    --query 'taskDefinitionArns' \
    --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$' || true)

  if [ -z "$TASK_DEF_ARNS" ]; then
    echo "  No task definitions found for $SERVICE."
    continue
  fi

  TOTAL_DEFS=$(echo "$TASK_DEF_ARNS" | wc -l | tr -d ' ')
  TO_DELETE=$((TOTAL_DEFS - KEEP_TASK_DEF_REVISIONS))

  echo "  Found $TOTAL_DEFS task definitions, will keep $KEEP_TASK_DEF_REVISIONS, delete $TO_DELETE"

  if [ "$TO_DELETE" -le 0 ]; then
    echo "  Nothing to clean up."
    continue
  fi

  OLD_DEFS=$(echo "$TASK_DEF_ARNS" | tail -n "$TO_DELETE")

  echo "  Will deregister:"
  echo "$OLD_DEFS" | sed 's/^/    /'

  if confirm "Deregister $TO_DELETE old task definitions for $SERVICE?"; then
    while IFS= read -r ARN; do
      if [ -n "$ARN" ]; then
        aws ecs deregister-task-definition \
          --task-definition "$ARN" \
          --region "$AWS_REGION" \
          --output text > /dev/null 2>&1 && \
          echo "  Deregistered: $ARN" || \
          echo "  WARNING: Failed to deregister $ARN"
        ACTIONS_TAKEN+=("ECS: deregistered task def $ARN")
      fi
    done <<< "$OLD_DEFS"
  fi
done

# ─── Step 3: Remove untagged ECR images ──────────────────────────────────
echo ""
echo "=== Step 3: Removing untagged ECR images ==="
for REPO in "${ECR_IMAGES[@]}"; do
  echo ""
  echo "Checking $REPO for untagged images..."

  UNTAGGED_DIGESTS=$(aws ecr list-images \
    --repository-name "$REPO" \
    --filter tagStatus=UNTAGGED \
    --region "$AWS_REGION" \
    --query 'imageIds[*].imageDigest' \
    --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$' || true)

  if [ -z "$UNTAGGED_DIGESTS" ]; then
    echo "  No untagged images in $REPO."
    continue
  fi

  COUNT=$(echo "$UNTAGGED_DIGESTS" | wc -l | tr -d ' ')
  echo "  Found $COUNT untagged image(s)."

  if confirm "Delete $COUNT untagged images from '$REPO'?"; then
    # Build the image IDs JSON for batch deletion
    IMAGE_IDS=$(echo "$UNTAGGED_DIGESTS" | python3 -c "
import sys, json
digests = [d.strip() for d in sys.stdin.read().splitlines() if d.strip()]
print(json.dumps([{'imageDigest': d} for d in digests]))
")
    aws ecr batch-delete-image \
      --repository-name "$REPO" \
      --image-ids "$IMAGE_IDS" \
      --region "$AWS_REGION" \
      --output text > /dev/null 2>&1 && \
      echo "  Deleted $COUNT untagged images from $REPO." || \
      echo "  WARNING: Failed to delete some images from $REPO"
    ACTIONS_TAKEN+=("ECR: deleted $COUNT untagged images from $REPO")
  fi
done

# ─── Step 4: Delete old CloudWatch log streams (>30 days) ────────────────
echo ""
echo "=== Step 4: Cleaning old CloudWatch log streams (>$LOG_STREAM_RETENTION_DAYS days) ==="
CUTOFF_EPOCH=$(python3 -c "
import time
print(int((time.time() - ($LOG_STREAM_RETENTION_DAYS * 86400)) * 1000))
")
echo "Deleting log streams with last event before $(date -d "@$((CUTOFF_EPOCH / 1000))" 2>/dev/null || date -r "$((CUTOFF_EPOCH / 1000))" 2>/dev/null || echo 'cutoff date')..."

LOG_GROUPS=$(aws logs describe-log-groups \
  --log-group-name-prefix "/aws/ecs/renewable-energy" \
  --region "$AWS_REGION" \
  --query 'logGroups[*].logGroupName' \
  --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$' || true)

DELETED_STREAMS=0
for LOG_GROUP in $LOG_GROUPS; do
  echo ""
  echo "Processing log group: $LOG_GROUP"

  OLD_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --order-by LastEventTime \
    --descending \
    --region "$AWS_REGION" \
    --query "logStreams[?lastEventTimestamp<\`$CUTOFF_EPOCH\`].logStreamName" \
    --output text 2>/dev/null | tr '\t' '\n' | grep -v '^$' || true)

  if [ -z "$OLD_STREAMS" ]; then
    echo "  No old log streams in $LOG_GROUP."
    continue
  fi

  COUNT=$(echo "$OLD_STREAMS" | wc -l | tr -d ' ')
  echo "  Found $COUNT log streams older than $LOG_STREAM_RETENTION_DAYS days."

  if confirm "Delete $COUNT old log streams from '$LOG_GROUP'?"; then
    while IFS= read -r STREAM; do
      if [ -n "$STREAM" ]; then
        aws logs delete-log-stream \
          --log-group-name "$LOG_GROUP" \
          --log-stream-name "$STREAM" \
          --region "$AWS_REGION" \
          2>/dev/null && DELETED_STREAMS=$((DELETED_STREAMS + 1)) || true
      fi
    done <<< "$OLD_STREAMS"
    echo "  Deleted $COUNT log streams."
    ACTIONS_TAKEN+=("CloudWatch: deleted $COUNT log streams from $LOG_GROUP")
  fi
done

# ─── Step 5: Clean up S3 artifact bucket ─────────────────────────────────
echo ""
echo "=== Step 5: CodePipeline S3 artifact bucket cleanup ==="
echo "Artifact bucket: $ARTIFACT_BUCKET"

BUCKET_EXISTS=$(aws s3api head-bucket \
  --bucket "$ARTIFACT_BUCKET" \
  --region "$AWS_REGION" \
  2>/dev/null && echo "yes" || echo "no")

if [ "$BUCKET_EXISTS" = "no" ]; then
  echo "  Bucket '$ARTIFACT_BUCKET' does not exist. Skipping."
else
  # Get bucket size
  BUCKET_SIZE=$(aws s3api list-objects-v2 \
    --bucket "$ARTIFACT_BUCKET" \
    --query 'sum(Contents[*].Size)' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "0")

  echo "  Bucket size: $(python3 -c "print(f'{int(\"$BUCKET_SIZE\" or 0) / 1024 / 1024:.1f} MB')" 2>/dev/null || echo "unknown")"

  if confirm "Empty S3 artifact bucket '$ARTIFACT_BUCKET' (removes ALL pipeline artifacts)?"; then
    echo "  Removing all objects from $ARTIFACT_BUCKET..."
    aws s3 rm "s3://$ARTIFACT_BUCKET" --recursive --region "$AWS_REGION" 2>&1 || true
    echo "  Bucket emptied."
    ACTIONS_TAKEN+=("S3: emptied artifact bucket $ARTIFACT_BUCKET")

    if [ "$DELETE_BUCKET" = "true" ]; then
      if confirm "PERMANENTLY DELETE S3 bucket '$ARTIFACT_BUCKET'?"; then
        aws s3api delete-bucket \
          --bucket "$ARTIFACT_BUCKET" \
          --region "$AWS_REGION" && \
          echo "  Bucket $ARTIFACT_BUCKET deleted." || \
          echo "  WARNING: Failed to delete bucket (may need versioned objects deleted first)"
        ACTIONS_TAKEN+=("S3: deleted bucket $ARTIFACT_BUCKET")
      fi
    fi
  fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " Cleanup Summary — $ENVIRONMENT"
echo "========================================"
if [ ${#ACTIONS_TAKEN[@]} -eq 0 ]; then
  echo "No actions taken."
else
  echo "Actions completed:"
  for ACTION in "${ACTIONS_TAKEN[@]}"; do
    echo "  - $ACTION"
  done
fi
echo ""
echo "Cleanup complete."
