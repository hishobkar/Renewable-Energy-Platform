#!/usr/bin/env bash
# push-images.sh — Tag and push all 6 Docker images to AWS ECR.
# Usage: ./push-images.sh [TAG] [AWS_ACCOUNT_ID] [AWS_REGION]
# Defaults: TAG=latest, reads AWS_ACCOUNT_ID and AWS_REGION from env or AWS CLI.

set -euo pipefail

TAG="${1:-latest}"
AWS_ACCOUNT_ID="${2:-${AWS_ACCOUNT_ID:-}}"
AWS_REGION="${3:-${AWS_REGION:-us-east-1}}"

ECR_REPO_PREFIX="renewable-energy"

IMAGES=(
  "renewable-energy/asset-service"
  "renewable-energy/telemetry-service"
  "renewable-energy/anomaly-detection-service"
  "renewable-energy/alert-service"
  "renewable-energy/simulator"
  "renewable-energy/dashboard"
)

echo "========================================"
echo " Renewable Energy Platform — Push Images"
echo "========================================"

# Resolve AWS account ID if not provided
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "Resolving AWS account ID from STS..."
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || true)
  if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "ERROR: Could not determine AWS_ACCOUNT_ID. Please pass it as argument 2 or set AWS_ACCOUNT_ID env var."
    exit 1
  fi
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Account  : $AWS_ACCOUNT_ID"
echo "Region   : $AWS_REGION"
echo "Registry : $ECR_REGISTRY"
echo "Tag      : $TAG"
echo "----------------------------------------"

# ECR login
echo ""
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"
echo "ECR login successful."

PUSH_ERRORS=()
PUSH_SUCCESS=()

for LOCAL_IMAGE in "${IMAGES[@]}"; do
  REPO_NAME="$LOCAL_IMAGE"
  ECR_IMAGE="$ECR_REGISTRY/$REPO_NAME"

  echo ""
  echo "Processing: $LOCAL_IMAGE"

  # Ensure ECR repository exists
  echo "  Ensuring ECR repository '$REPO_NAME' exists..."
  if aws ecr describe-repositories \
      --repository-names "$REPO_NAME" \
      --region "$AWS_REGION" \
      --output text \
      2>/dev/null; then
    echo "  Repository already exists."
  else
    echo "  Creating repository '$REPO_NAME'..."
    aws ecr create-repository \
      --repository-name "$REPO_NAME" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256 \
      --region "$AWS_REGION" \
      --output text
    echo "  Repository created."

    # Set lifecycle policy: keep last 20 tagged images, purge untagged after 1 day
    aws ecr put-lifecycle-policy \
      --repository-name "$REPO_NAME" \
      --region "$AWS_REGION" \
      --lifecycle-policy-text '{
        "rules": [
          {
            "rulePriority": 1,
            "description": "Keep last 20 tagged images",
            "selection": {
              "tagStatus": "tagged",
              "tagPrefixList": ["v", "latest"],
              "countType": "imageCountMoreThan",
              "countNumber": 20
            },
            "action": {"type": "expire"}
          },
          {
            "rulePriority": 2,
            "description": "Expire untagged images after 1 day",
            "selection": {
              "tagStatus": "untagged",
              "countType": "sinceImagePushed",
              "countUnit": "days",
              "countNumber": 1
            },
            "action": {"type": "expire"}
          }
        ]
      }' 2>/dev/null || true
  fi

  # Verify local image exists
  if ! docker image inspect "$LOCAL_IMAGE:$TAG" &>/dev/null; then
    echo "  WARNING: Local image $LOCAL_IMAGE:$TAG not found. Build it first with build-all.sh"
    PUSH_ERRORS+=("$LOCAL_IMAGE: local image not found (run build-all.sh first)")
    continue
  fi

  # Tag image for ECR
  echo "  Tagging $LOCAL_IMAGE:$TAG → $ECR_IMAGE:$TAG"
  docker tag "$LOCAL_IMAGE:$TAG" "$ECR_IMAGE:$TAG"
  docker tag "$LOCAL_IMAGE:$TAG" "$ECR_IMAGE:latest"

  # Push both tags
  PUSH_START=$(date +%s)
  echo "  Pushing $ECR_IMAGE:$TAG..."
  if docker push "$ECR_IMAGE:$TAG"; then
    echo "  Pushing $ECR_IMAGE:latest..."
    docker push "$ECR_IMAGE:latest"
    PUSH_END=$(date +%s)
    PUSH_TIME=$((PUSH_END - PUSH_START))
    echo "  [OK] Pushed $LOCAL_IMAGE in ${PUSH_TIME}s"
    PUSH_SUCCESS+=("$ECR_IMAGE:$TAG")
    PUSH_SUCCESS+=("$ECR_IMAGE:latest")
  else
    PUSH_END=$(date +%s)
    PUSH_TIME=$((PUSH_END - PUSH_START))
    echo "  [FAIL] Push failed for $LOCAL_IMAGE after ${PUSH_TIME}s"
    PUSH_ERRORS+=("$LOCAL_IMAGE: push failed")
  fi
done

echo ""
echo "========================================"
echo " Push Summary"
echo "========================================"

if [ ${#PUSH_SUCCESS[@]} -gt 0 ]; then
  echo "Successfully pushed:"
  for IMG in "${PUSH_SUCCESS[@]}"; do
    echo "  - $IMG"
  done
fi

if [ ${#PUSH_ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "FAILED:"
  for ERR in "${PUSH_ERRORS[@]}"; do
    echo "  - $ERR"
  done
  echo ""
  exit 1
else
  echo ""
  echo "All images pushed successfully."
  echo ""
  echo "ECR Registry: $ECR_REGISTRY"
  echo "Images tagged: $TAG and latest"
  exit 0
fi
