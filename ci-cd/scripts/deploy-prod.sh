#!/usr/bin/env bash
# deploy-prod.sh — Production deployment via AWS CodeDeploy blue/green.
# Validates staging, creates CloudWatch alarm-based rollback, deploys blue/green.
# On failure automatically calls rollback.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER="${ECS_CLUSTER_PROD:-renewable-energy-prod}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query 'Account' --output text)}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

CODEDEPLOY_APP="${CODEDEPLOY_APP:-renewable-energy-prod}"
CODEDEPLOY_GROUP="${CODEDEPLOY_GROUP:-renewable-energy-prod-dg}"

DEPLOY_MONITOR_TIMEOUT=1800   # 30 minutes
DEPLOY_POLL_INTERVAL=30
ALARM_EVALUATION_PERIOD=300

SERVICES=(
  "asset-service"
  "telemetry-service"
  "anomaly-detection-service"
  "alert-service"
  "simulator"
  "dashboard"
)

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_PREFIX="renewable-energy"

echo "========================================"
echo " Deploy to Production — Blue/Green"
echo "========================================"
echo "Cluster     : $CLUSTER"
echo "Region      : $AWS_REGION"
echo "Account     : $AWS_ACCOUNT_ID"
echo "Image Tag   : $IMAGE_TAG"
echo "CodeDeploy  : $CODEDEPLOY_APP / $CODEDEPLOY_GROUP"
echo "----------------------------------------"

# Step 0: Validate staging is healthy
echo ""
echo "=== Step 0: Validating staging environment ==="
if [ -f "$SCRIPT_DIR/smoke-test.sh" ]; then
  echo "Running smoke tests on staging..."
  if bash "$SCRIPT_DIR/smoke-test.sh" staging; then
    echo "[OK] Staging is healthy. Proceeding with production deployment."
  else
    echo "[FAIL] Staging smoke tests FAILED. Aborting production deployment."
    echo "       Fix staging issues before promoting to production."
    exit 1
  fi
else
  echo "WARNING: smoke-test.sh not found. Skipping staging validation."
fi

# Step 1: Create/update CloudWatch alarms for rollback
echo ""
echo "=== Step 1: Setting up CloudWatch alarm-based rollback ==="
for SERVICE in "${SERVICES[@]}"; do
  # Create CloudWatch alarms that will trigger rollback if error rate is high
  aws cloudwatch put-metric-alarm \
    --alarm-name "renewable-energy-prod-${SERVICE}-error-rate" \
    --alarm-description "High error rate alarm for ${SERVICE} in production" \
    --metric-name "5XXError" \
    --namespace "AWS/ApplicationELB" \
    --dimensions "Name=TargetGroup,Value=${SERVICE}-prod-tg" \
    --statistic "Sum" \
    --period 60 \
    --evaluation-periods 5 \
    --threshold 10 \
    --comparison-operator "GreaterThanThreshold" \
    --treat-missing-data "notBreaching" \
    --region "$AWS_REGION" \
    2>/dev/null || echo "  (Alarm for $SERVICE not created — target group may not exist yet)"
done
echo "CloudWatch alarms configured."

# Step 2: Update ECS task definitions with new images
echo ""
echo "=== Step 2: Registering new task definitions ==="
declare -A NEW_TASK_DEFS

for SERVICE in "${SERVICES[@]}"; do
  IMAGE_URI="$ECR_REGISTRY/$ECR_PREFIX/$SERVICE:$IMAGE_TAG"
  echo "Registering new task definition for $SERVICE (image: $IMAGE_URI)..."

  CURRENT_TASK_DEF=$(aws ecs describe-task-definition \
    --task-definition "$SERVICE" \
    --region "$AWS_REGION" \
    --query 'taskDefinition' \
    --output json 2>/dev/null || echo '{}')

  if [ "$CURRENT_TASK_DEF" = "{}" ]; then
    echo "  WARNING: No existing task definition for $SERVICE, skipping."
    continue
  fi

  NEW_TASK_DEF=$(echo "$CURRENT_TASK_DEF" | python3 -c "
import json, sys
td = json.load(sys.stdin)
for c in td.get('containerDefinitions', []):
    if c.get('name') == '$SERVICE':
        c['image'] = '$IMAGE_URI'
for key in ['taskDefinitionArn','revision','status','requiresAttributes',
            'placementConstraints','compatibilities','registeredAt','registeredBy']:
    td.pop(key, None)
print(json.dumps(td))
")

  NEW_ARN=$(aws ecs register-task-definition \
    --region "$AWS_REGION" \
    --cli-input-json "$NEW_TASK_DEF" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

  NEW_TASK_DEFS["$SERVICE"]="$NEW_ARN"
  echo "  Registered: $NEW_ARN"
done

# Step 3: Create CodeDeploy blue/green deployment
echo ""
echo "=== Step 3: Creating CodeDeploy blue/green deployment ==="

# Generate AppSpec
cat > /tmp/appspec.json << APPSPEC_EOF
{
  "version": 1,
  "Resources": [
    {
      "TargetService": {
        "Type": "AWS::ECS::Service",
        "Properties": {
          "TaskDefinition": "${NEW_TASK_DEFS[asset-service]:-<TASK_DEFINITION>}",
          "LoadBalancerInfo": {
            "ContainerName": "asset-service",
            "ContainerPort": 5001
          }
        }
      }
    }
  ],
  "Hooks": [
    {
      "BeforeAllowTraffic": "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:renewable-energy-pre-traffic-hook"
    },
    {
      "AfterAllowTraffic": "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:renewable-energy-post-traffic-hook"
    }
  ]
}
APPSPEC_EOF

APPSPEC_CONTENT=$(cat /tmp/appspec.json | tr -d '\n')

DEPLOYMENT_ID=$(aws deploy create-deployment \
  --application-name "$CODEDEPLOY_APP" \
  --deployment-group-name "$CODEDEPLOY_GROUP" \
  --revision "revisionType=AppSpecContent,appSpecContent={content='$APPSPEC_CONTENT'}" \
  --deployment-config-name "CodeDeployDefault.ECSLinear10PercentEvery1Minutes" \
  --description "Production deployment image=$IMAGE_TAG" \
  --auto-rollback-configuration "enabled=true,events=DEPLOYMENT_FAILURE,DEPLOYMENT_STOP_ON_ALARM,DEPLOYMENT_STOP_ON_REQUEST" \
  --region "$AWS_REGION" \
  --query 'deploymentId' \
  --output text 2>/dev/null || echo "")

if [ -z "$DEPLOYMENT_ID" ]; then
  echo "WARNING: CodeDeploy deployment could not be created. Falling back to ECS force-new-deployment."

  for SERVICE in "${SERVICES[@]}"; do
    TASK_DEF="${NEW_TASK_DEFS[$SERVICE]:-}"
    if [ -n "$TASK_DEF" ]; then
      aws ecs update-service \
        --cluster "$CLUSTER" \
        --service "$SERVICE" \
        --task-definition "$TASK_DEF" \
        --force-new-deployment \
        --region "$AWS_REGION" \
        --output text > /dev/null
      echo "  Deployed $SERVICE via ECS."
    fi
  done
  DEPLOYMENT_METHOD="ECS"
else
  echo "CodeDeploy deployment created: $DEPLOYMENT_ID"
  DEPLOYMENT_METHOD="CodeDeploy"
fi

# Step 4: Monitor deployment progress
echo ""
echo "=== Step 4: Monitoring deployment (timeout: ${DEPLOY_MONITOR_TIMEOUT}s) ==="
ELAPSED=0
DEPLOY_STATUS="InProgress"

if [ "$DEPLOYMENT_METHOD" = "CodeDeploy" ]; then
  while [ $ELAPSED -lt $DEPLOY_MONITOR_TIMEOUT ]; do
    DEPLOY_STATUS=$(aws deploy get-deployment \
      --deployment-id "$DEPLOYMENT_ID" \
      --region "$AWS_REGION" \
      --query 'deploymentInfo.status' \
      --output text 2>/dev/null || echo "Unknown")

    echo "  [$ELAPSED s] Deployment $DEPLOYMENT_ID: $DEPLOY_STATUS"

    case "$DEPLOY_STATUS" in
      Succeeded)
        echo "[OK] Deployment succeeded!"
        break
        ;;
      Failed|Stopped)
        echo "[FAIL] Deployment failed with status: $DEPLOY_STATUS"
        echo "Triggering rollback..."
        if [ -f "$SCRIPT_DIR/rollback.sh" ]; then
          bash "$SCRIPT_DIR/rollback.sh" prod
        fi
        exit 1
        ;;
      InProgress|Created|Queued|Ready)
        sleep $DEPLOY_POLL_INTERVAL
        ELAPSED=$((ELAPSED + DEPLOY_POLL_INTERVAL))
        ;;
      *)
        echo "  Unknown status: $DEPLOY_STATUS"
        sleep $DEPLOY_POLL_INTERVAL
        ELAPSED=$((ELAPSED + DEPLOY_POLL_INTERVAL))
        ;;
    esac
  done

  if [ "$DEPLOY_STATUS" != "Succeeded" ]; then
    echo "[FAIL] Deployment timed out after ${DEPLOY_MONITOR_TIMEOUT}s"
    echo "Triggering rollback..."
    if [ -f "$SCRIPT_DIR/rollback.sh" ]; then
      bash "$SCRIPT_DIR/rollback.sh" prod
    fi
    exit 1
  fi
else
  # ECS deployment — wait for stability
  for SERVICE in "${SERVICES[@]}"; do
    echo "Waiting for $SERVICE to stabilize..."
    aws ecs wait services-stable \
      --cluster "$CLUSTER" \
      --services "$SERVICE" \
      --region "$AWS_REGION" || {
      echo "[FAIL] $SERVICE did not stabilize."
      bash "$SCRIPT_DIR/rollback.sh" prod || true
      exit 1
    }
    echo "  $SERVICE is stable."
  done
fi

# Step 5: Run smoke tests on prod
echo ""
echo "=== Step 5: Running production smoke tests ==="
if [ -f "$SCRIPT_DIR/smoke-test.sh" ]; then
  if bash "$SCRIPT_DIR/smoke-test.sh" prod; then
    echo "[OK] Production smoke tests passed."
  else
    echo "[FAIL] Production smoke tests FAILED after deployment."
    echo "Triggering rollback..."
    if [ -f "$SCRIPT_DIR/rollback.sh" ]; then
      bash "$SCRIPT_DIR/rollback.sh" prod
    fi
    exit 1
  fi
fi

echo ""
echo "========================================"
echo " Production Deployment SUCCEEDED"
echo "========================================"
echo "Image tag       : $IMAGE_TAG"
echo "Deployment method: $DEPLOYMENT_METHOD"
[ -n "${DEPLOYMENT_ID:-}" ] && echo "Deployment ID    : $DEPLOYMENT_ID"
echo ""
