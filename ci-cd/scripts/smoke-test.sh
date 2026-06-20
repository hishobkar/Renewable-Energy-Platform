#!/usr/bin/env bash
# smoke-test.sh — Quick health and API smoke tests for all services.
# Usage: ./smoke-test.sh [ENVIRONMENT]
# Exits 1 if any test fails.

set -euo pipefail

ENVIRONMENT="${1:-dev}"
MAX_RETRIES=3
RETRY_DELAY=5
CURL_TIMEOUT=30

# Set service URLs based on environment
case "$ENVIRONMENT" in
  dev)
    ASSET_URL="${ASSET_SERVICE_URL:-http://renewable-energy-dev.example.com:5001}"
    TELEMETRY_URL="${TELEMETRY_SERVICE_URL:-http://renewable-energy-dev.example.com:5002}"
    ANOMALY_URL="${ANOMALY_SERVICE_URL:-http://renewable-energy-dev.example.com:5003}"
    ALERT_URL="${ALERT_SERVICE_URL:-http://renewable-energy-dev.example.com:5004}"
    ;;
  staging)
    ASSET_URL="${ASSET_SERVICE_URL:-http://renewable-energy-staging.example.com:5001}"
    TELEMETRY_URL="${TELEMETRY_SERVICE_URL:-http://renewable-energy-staging.example.com:5002}"
    ANOMALY_URL="${ANOMALY_SERVICE_URL:-http://renewable-energy-staging.example.com:5003}"
    ALERT_URL="${ALERT_SERVICE_URL:-http://renewable-energy-staging.example.com:5004}"
    ;;
  prod)
    ASSET_URL="${ASSET_SERVICE_URL:-http://renewable-energy.example.com:5001}"
    TELEMETRY_URL="${TELEMETRY_SERVICE_URL:-http://renewable-energy.example.com:5002}"
    ANOMALY_URL="${ANOMALY_SERVICE_URL:-http://renewable-energy.example.com:5003}"
    ALERT_URL="${ALERT_SERVICE_URL:-http://renewable-energy.example.com:5004}"
    ;;
  local)
    ASSET_URL="${ASSET_SERVICE_URL:-http://localhost:5001}"
    TELEMETRY_URL="${TELEMETRY_SERVICE_URL:-http://localhost:5002}"
    ANOMALY_URL="${ANOMALY_SERVICE_URL:-http://localhost:5003}"
    ALERT_URL="${ALERT_SERVICE_URL:-http://localhost:5004}"
    ;;
  *)
    echo "ERROR: Unknown environment '$ENVIRONMENT'. Must be dev, staging, prod, or local."
    exit 1
    ;;
esac

PASS=0
FAIL=0
SKIP=0
declare -a FAILURES=()

echo "========================================"
echo " Smoke Tests — $ENVIRONMENT"
echo "========================================"
echo "Asset service     : $ASSET_URL"
echo "Telemetry service : $TELEMETRY_URL"
echo "Anomaly service   : $ANOMALY_URL"
echo "Alert service     : $ALERT_URL"
echo "----------------------------------------"
echo ""

# ─── Helper: HTTP check with retry ──────────────────────────────────────────
check_http() {
  local TEST_NAME="$1"
  local URL="$2"
  local EXPECTED_STATUS="$3"
  local METHOD="${4:-GET}"
  local DATA="${5:-}"
  local CONTENT_TYPE="${6:-application/json}"

  local ATTEMPT=1
  local STATUS=""

  while [ $ATTEMPT -le $MAX_RETRIES ]; do
    if [ "$METHOD" = "POST" ] && [ -n "$DATA" ]; then
      STATUS=$(curl -s -o /tmp/smoke-response.txt -w "%{http_code}" \
        --max-time "$CURL_TIMEOUT" \
        -X POST \
        -H "Content-Type: $CONTENT_TYPE" \
        -d "$DATA" \
        "$URL" 2>/dev/null || echo "000")
    else
      STATUS=$(curl -s -o /tmp/smoke-response.txt -w "%{http_code}" \
        --max-time "$CURL_TIMEOUT" \
        "$URL" 2>/dev/null || echo "000")
    fi

    if [ "$STATUS" = "$EXPECTED_STATUS" ]; then
      break
    fi

    if [ $ATTEMPT -lt $MAX_RETRIES ]; then
      echo "  Attempt $ATTEMPT/$MAX_RETRIES: got $STATUS, expected $EXPECTED_STATUS. Retrying in ${RETRY_DELAY}s..."
      sleep $RETRY_DELAY
    fi
    ATTEMPT=$((ATTEMPT + 1))
  done

  RESPONSE_BODY=$(cat /tmp/smoke-response.txt 2>/dev/null || echo "")

  if [ "$STATUS" = "$EXPECTED_STATUS" ]; then
    echo "[PASS] $TEST_NAME (HTTP $STATUS)"
    PASS=$((PASS + 1))
    return 0
  else
    echo "[FAIL] $TEST_NAME"
    echo "       URL: $URL"
    echo "       Expected: HTTP $EXPECTED_STATUS"
    echo "       Got     : HTTP $STATUS"
    if [ -n "$RESPONSE_BODY" ]; then
      echo "       Response: $(echo "$RESPONSE_BODY" | head -c 200)"
    fi
    FAIL=$((FAIL + 1))
    FAILURES+=("$TEST_NAME: expected $EXPECTED_STATUS got $STATUS")
    return 1
  fi
}

# ─── Health checks ─────────────────────────────────────────────────────────
echo "--- Health Checks ---"
check_http "asset-service /health"            "$ASSET_URL/health"    "200" || true
check_http "telemetry-service /health"        "$TELEMETRY_URL/health" "200" || true
check_http "anomaly-detection-service /health" "$ANOMALY_URL/health"  "200" || true
check_http "alert-service /health"            "$ALERT_URL/health"    "200" || true

echo ""

# ─── API endpoint checks ───────────────────────────────────────────────────
echo "--- API Endpoint Checks ---"

# Asset service: GET /api/v1/assets
check_http "asset-service GET /api/v1/assets" \
  "$ASSET_URL/api/v1/assets" \
  "200" || true

# Asset service: GET /api/v1/assets (check response is valid JSON array)
if curl -s --max-time "$CURL_TIMEOUT" "$ASSET_URL/api/v1/assets" 2>/dev/null | \
    python3 -c "import json,sys; data=json.load(sys.stdin); assert isinstance(data, (list, dict))" 2>/dev/null; then
  echo "[PASS] asset-service GET /api/v1/assets returns valid JSON"
  PASS=$((PASS + 1))
else
  echo "[FAIL] asset-service GET /api/v1/assets — invalid JSON response"
  FAIL=$((FAIL + 1))
  FAILURES+=("asset-service /api/v1/assets: invalid JSON")
fi

# Telemetry service: GET /api/v1/telemetry
check_http "telemetry-service GET /api/v1/telemetry" \
  "$TELEMETRY_URL/api/v1/telemetry" \
  "200" || true

# Anomaly detection: GET /api/v1/anomalies
check_http "anomaly-detection-service GET /api/v1/anomalies" \
  "$ANOMALY_URL/api/v1/anomalies" \
  "200" || true

# Alert service: GET /api/v1/alerts
check_http "alert-service GET /api/v1/alerts" \
  "$ALERT_URL/api/v1/alerts" \
  "200" || true

echo ""

# ─── OpenAPI / docs checks (optional) ──────────────────────────────────────
echo "--- API Documentation Checks ---"
for SVC_URL_PAIR in "$ASSET_URL asset-service" "$TELEMETRY_URL telemetry-service" "$ANOMALY_URL anomaly-detection-service" "$ALERT_URL alert-service"; do
  SVC_URL=$(echo "$SVC_URL_PAIR" | cut -d' ' -f1)
  SVC_NAME=$(echo "$SVC_URL_PAIR" | cut -d' ' -f2)

  # Try /docs (FastAPI) or /swagger (ASP.NET) — non-critical
  DOCS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$SVC_URL/docs" 2>/dev/null || echo "000")
  SWAGGER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$SVC_URL/swagger" 2>/dev/null || echo "000")

  if [ "$DOCS_STATUS" = "200" ] || [ "$SWAGGER_STATUS" = "200" ]; then
    echo "[PASS] $SVC_NAME API docs accessible"
    PASS=$((PASS + 1))
  else
    echo "[SKIP] $SVC_NAME API docs not found (may be disabled in $ENVIRONMENT)"
    SKIP=$((SKIP + 1))
  fi
done

echo ""

# Write results to JSON file
RESULT_STATUS="passed"
[ "$FAIL" -gt 0 ] && RESULT_STATUS="failed"

cat > smoke-test-results.json << RESULTEOF
{
  "environment": "$ENVIRONMENT",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "result": "$RESULT_STATUS",
  "passed": $PASS,
  "failed": $FAIL,
  "skipped": $SKIP,
  "failures": $(python3 -c "import json; print(json.dumps(${FAILURES[@]+"${FAILURES[*]}"} if False else $(printf '%s\n' "${FAILURES[@]:-}" | python3 -c "import json,sys; lines=[l for l in sys.stdin.read().splitlines() if l]; print(json.dumps(lines))")))" 2>/dev/null || echo "[]")
}
RESULTEOF

# Final summary
echo "========================================"
echo " Smoke Test Summary — $ENVIRONMENT"
echo "========================================"
printf "PASSED : %d\n" "$PASS"
printf "FAILED : %d\n" "$FAIL"
printf "SKIPPED: %d\n" "$SKIP"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "FAILED tests:"
  for F in "${FAILURES[@]}"; do
    echo "  - $F"
  done
  echo ""
  echo "Status: SMOKE TESTS FAILED"
  exit 1
else
  echo "Status: ALL SMOKE TESTS PASSED"
  exit 0
fi
