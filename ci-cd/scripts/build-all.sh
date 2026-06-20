#!/usr/bin/env bash
# build-all.sh — Build all 6 Docker images for the Renewable Energy Platform locally.
# Usage: ./build-all.sh [TAG]
# Default TAG: latest
# Sets BUILD_TAG env var. Exits non-zero if any build fails.

set -euo pipefail

BUILD_TAG="${1:-latest}"
export BUILD_TAG

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Service name → directory name under services/
declare -A SERVICES=(
  ["renewable-energy/asset-service"]="asset-service"
  ["renewable-energy/telemetry-service"]="telemetry-service"
  ["renewable-energy/anomaly-detection-service"]="anomaly-detection-service"
  ["renewable-energy/alert-service"]="alert-service"
  ["renewable-energy/simulator"]="simulator"
  ["renewable-energy/dashboard"]="dashboard"
)

BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BUILD_ERRORS=()
TOTAL_START=$(date +%s)

echo "========================================"
echo " Renewable Energy Platform — Build All"
echo "========================================"
echo "Tag       : $BUILD_TAG"
echo "Build date: $BUILD_DATE"
echo "Root dir  : $PROJECT_ROOT"
echo "----------------------------------------"

for IMAGE_NAME in "${!SERVICES[@]}"; do
  SERVICE_DIR="${SERVICES[$IMAGE_NAME]}"
  CONTEXT_PATH="$PROJECT_ROOT/services/$SERVICE_DIR"
  DOCKERFILE="$CONTEXT_PATH/Dockerfile"

  if [ ! -d "$CONTEXT_PATH" ]; then
    echo ""
    echo "[SKIP] $IMAGE_NAME — directory not found: $CONTEXT_PATH"
    BUILD_ERRORS+=("$IMAGE_NAME: context directory missing")
    continue
  fi

  if [ ! -f "$DOCKERFILE" ]; then
    echo ""
    echo "[SKIP] $IMAGE_NAME — Dockerfile not found: $DOCKERFILE"
    BUILD_ERRORS+=("$IMAGE_NAME: Dockerfile missing")
    continue
  fi

  echo ""
  echo "Building: $IMAGE_NAME:$BUILD_TAG"
  echo "Context : $CONTEXT_PATH"
  IMAGE_START=$(date +%s)

  if docker build \
      --build-arg BUILD_VERSION="$BUILD_TAG" \
      --build-arg BUILD_DATE="$BUILD_DATE" \
      --label "org.opencontainers.image.version=$BUILD_TAG" \
      --label "org.opencontainers.image.created=$BUILD_DATE" \
      --label "org.opencontainers.image.source=https://github.com/Hishobkar/Renewable-Energy-Platform" \
      -t "$IMAGE_NAME:$BUILD_TAG" \
      -t "$IMAGE_NAME:latest" \
      -f "$DOCKERFILE" \
      "$CONTEXT_PATH" \
      2>&1; then
    IMAGE_END=$(date +%s)
    BUILD_TIME=$((IMAGE_END - IMAGE_START))
    echo "[OK] $IMAGE_NAME:$BUILD_TAG built in ${BUILD_TIME}s"
  else
    IMAGE_END=$(date +%s)
    BUILD_TIME=$((IMAGE_END - IMAGE_START))
    echo "[FAIL] $IMAGE_NAME:$BUILD_TAG failed after ${BUILD_TIME}s"
    BUILD_ERRORS+=("$IMAGE_NAME: build failed")
  fi
done

TOTAL_END=$(date +%s)
TOTAL_TIME=$((TOTAL_END - TOTAL_START))

echo ""
echo "========================================"
echo " Build Summary"
echo "========================================"
echo "Total time: ${TOTAL_TIME}s"
echo "Tag used  : $BUILD_TAG"
echo ""

if [ ${#BUILD_ERRORS[@]} -eq 0 ]; then
  echo "All images built successfully:"
  for IMAGE_NAME in "${!SERVICES[@]}"; do
    echo "  - $IMAGE_NAME:$BUILD_TAG"
  done
  echo ""
  echo "To push images, run:"
  echo "  ./push-images.sh $BUILD_TAG <AWS_ACCOUNT_ID> <AWS_REGION>"
  exit 0
else
  echo "The following builds FAILED:"
  for ERR in "${BUILD_ERRORS[@]}"; do
    echo "  - $ERR"
  done
  echo ""
  echo "Fix the errors above and re-run."
  exit 1
fi
