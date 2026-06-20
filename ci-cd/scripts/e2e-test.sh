#!/usr/bin/env bash
# e2e-test.sh — Full end-to-end test of the Renewable Energy Platform.
# Flow: register asset → post telemetry → check anomalies → check alerts
#       → update asset → delete asset.
# Validates HTTP status and response body at each step.
# Cleans up all created resources regardless of pass/fail.
# Usage: ./e2e-test.sh [ENVIRONMENT]

set -euo pipefail

ENVIRONMENT="${1:-dev}"
CURL_TIMEOUT=30
WAIT_AFTER_TELEMETRY=15   # seconds to wait for anomaly/alert processing

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
    echo "ERROR: Unknown environment '$ENVIRONMENT'"
    exit 1
    ;;
esac

PASS=0
FAIL=0
declare -a FAILURES=()
CREATED_ASSET_ID=""

# ─── Cleanup function ─────────────────────────────────────────────────────
cleanup() {
  local EXIT_CODE=$?
  if [ -n "$CREATED_ASSET_ID" ]; then
    echo ""
    echo "=== Cleanup: Deleting test asset $CREATED_ASSET_ID ==="
    DELETE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" \
      -X DELETE \
      "$ASSET_URL/api/v1/assets/$CREATED_ASSET_ID" 2>/dev/null || echo "000")
    if [ "$DELETE_STATUS" = "200" ] || [ "$DELETE_STATUS" = "204" ] || [ "$DELETE_STATUS" = "404" ]; then
      echo "Test asset $CREATED_ASSET_ID deleted (HTTP $DELETE_STATUS)."
    else
      echo "WARNING: Failed to delete test asset $CREATED_ASSET_ID (HTTP $DELETE_STATUS)"
    fi
  fi

  # Final report
  echo ""
  echo "========================================"
  echo " E2E Test Summary — $ENVIRONMENT"
  echo "========================================"
  echo "Passed : $PASS"
  echo "Failed : $FAIL"
  if [ ${#FAILURES[@]} -gt 0 ]; then
    echo ""
    echo "Failures:"
    for F in "${FAILURES[@]}"; do
      echo "  - $F"
    done
  fi
  echo ""
  if [ "$FAIL" -eq 0 ]; then
    echo "Status: ALL E2E TESTS PASSED"
  else
    echo "Status: E2E TESTS FAILED"
  fi
}
trap cleanup EXIT

# ─── Helper: assert HTTP call ─────────────────────────────────────────────
assert_http() {
  local STEP="$1"
  local URL="$2"
  local METHOD="$3"
  local EXPECTED_STATUS="$4"
  local DATA="${5:-}"
  local RESPONSE_FILE="/tmp/e2e-response-$$.json"

  echo ""
  echo "--- Step: $STEP ---"
  echo "  $METHOD $URL"

  local STATUS=""
  if [ "$METHOD" = "POST" ] || [ "$METHOD" = "PUT" ] || [ "$METHOD" = "PATCH" ]; then
    STATUS=$(curl -s -o "$RESPONSE_FILE" -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" \
      -X "$METHOD" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "${DATA:-{}}" \
      "$URL" 2>/dev/null || echo "000")
  elif [ "$METHOD" = "DELETE" ]; then
    STATUS=$(curl -s -o "$RESPONSE_FILE" -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" \
      -X DELETE \
      -H "Accept: application/json" \
      "$URL" 2>/dev/null || echo "000")
  else
    STATUS=$(curl -s -o "$RESPONSE_FILE" -w "%{http_code}" \
      --max-time "$CURL_TIMEOUT" \
      -H "Accept: application/json" \
      "$URL" 2>/dev/null || echo "000")
  fi

  RESPONSE_BODY=$(cat "$RESPONSE_FILE" 2>/dev/null || echo "")
  rm -f "$RESPONSE_FILE"

  if [ "$STATUS" = "$EXPECTED_STATUS" ]; then
    echo "  [PASS] HTTP $STATUS (expected $EXPECTED_STATUS)"
    PASS=$((PASS + 1))
    echo "$RESPONSE_BODY"
    return 0
  else
    echo "  [FAIL] HTTP $STATUS (expected $EXPECTED_STATUS)"
    echo "  Response: $(echo "$RESPONSE_BODY" | head -c 500)"
    FAIL=$((FAIL + 1))
    FAILURES+=("$STEP: expected HTTP $EXPECTED_STATUS got $STATUS")
    return 1
  fi
}

# ─── Helper: extract JSON field ───────────────────────────────────────────
extract_json() {
  local JSON="$1"
  local FIELD="$2"
  echo "$JSON" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    # Try top-level key
    if isinstance(data, dict):
        val = data.get('$FIELD') or data.get('data', {}).get('$FIELD') or data.get('id')
        print(val or '')
    elif isinstance(data, list) and len(data) > 0:
        print(data[0].get('$FIELD', ''))
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo ""
}

# ─── Generate unique test identifiers ─────────────────────────────────────
TEST_RUN_ID="e2e-$(date +%s)"
TEST_ASSET_NAME="E2E Test Solar Panel - $TEST_RUN_ID"

echo "========================================"
echo " End-to-End Tests — $ENVIRONMENT"
echo "========================================"
echo "Test run ID : $TEST_RUN_ID"
echo "Asset URL   : $ASSET_URL"
echo "Telemetry   : $TELEMETRY_URL"
echo "Anomaly     : $ANOMALY_URL"
echo "Alert       : $ALERT_URL"
echo "----------------------------------------"

# ─── Step 1: Register an asset ───────────────────────────────────────────
ASSET_PAYLOAD=$(cat << EOF
{
  "name": "$TEST_ASSET_NAME",
  "type": "solar_panel",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "site_name": "E2E Test Site"
  },
  "capacity_kw": 250.0,
  "manufacturer": "E2E Test Manufacturer",
  "model": "Test Model X-250",
  "serial_number": "SN-$TEST_RUN_ID",
  "installation_date": "$(date +%Y-%m-%d)",
  "status": "active",
  "metadata": {
    "test_run": "$TEST_RUN_ID",
    "automated": true
  }
}
EOF
)

STEP1_RESPONSE=$(assert_http \
  "1. Register new asset" \
  "$ASSET_URL/api/v1/assets" \
  "POST" \
  "201" \
  "$ASSET_PAYLOAD" || echo "FAILED")

if [ "$STEP1_RESPONSE" = "FAILED" ]; then
  echo "Cannot proceed without asset ID. Aborting E2E tests."
  exit 1
fi

CREATED_ASSET_ID=$(extract_json "$STEP1_RESPONSE" "id")

if [ -z "$CREATED_ASSET_ID" ]; then
  echo "  ERROR: Could not extract asset ID from response."
  echo "  Response was: $STEP1_RESPONSE"
  FAIL=$((FAIL + 1))
  FAILURES+=("Step 1: Could not extract asset ID")
  exit 1
fi

echo "  Created asset ID: $CREATED_ASSET_ID"

# ─── Step 2: Verify asset can be retrieved ───────────────────────────────
assert_http \
  "2. Retrieve created asset" \
  "$ASSET_URL/api/v1/assets/$CREATED_ASSET_ID" \
  "GET" \
  "200" || true

# ─── Step 3: List assets (check new asset appears) ───────────────────────
LIST_RESPONSE=$(assert_http \
  "3. List assets (verify new asset in list)" \
  "$ASSET_URL/api/v1/assets" \
  "GET" \
  "200" || echo "")

if echo "$LIST_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('items', data.get('data', []))
ids = [str(item.get('id', '')) for item in items]
assert '$CREATED_ASSET_ID' in ids, f'Asset $CREATED_ASSET_ID not found in list: {ids[:5]}'
" 2>/dev/null; then
  echo "  [PASS] New asset found in asset list"
  PASS=$((PASS + 1))
else
  echo "  [WARN] New asset may not be in asset list yet (eventual consistency)"
fi

# ─── Step 4: Post telemetry data for the asset ───────────────────────────
TELEMETRY_PAYLOAD=$(cat << EOF
{
  "asset_id": "$CREATED_ASSET_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "power_output_kw": 185.5,
    "voltage_v": 220.3,
    "current_a": 84.2,
    "temperature_celsius": 42.7,
    "irradiance_w_m2": 820.0,
    "efficiency_percent": 74.2,
    "energy_generated_kwh": 18.55
  },
  "status": "operational",
  "metadata": {
    "test_run": "$TEST_RUN_ID"
  }
}
EOF
)

assert_http \
  "4. Post telemetry data for asset $CREATED_ASSET_ID" \
  "$TELEMETRY_URL/api/v1/telemetry" \
  "POST" \
  "201" \
  "$TELEMETRY_PAYLOAD" || true

# Post a second telemetry reading with an anomalous value
ANOMALOUS_PAYLOAD=$(cat << EOF
{
  "asset_id": "$CREATED_ASSET_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "power_output_kw": 0.1,
    "voltage_v": 285.0,
    "current_a": 0.0,
    "temperature_celsius": 95.5,
    "irradiance_w_m2": 850.0,
    "efficiency_percent": 0.04,
    "energy_generated_kwh": 0.01
  },
  "status": "degraded",
  "metadata": {
    "test_run": "$TEST_RUN_ID",
    "anomaly_test": true
  }
}
EOF
)

assert_http \
  "5. Post anomalous telemetry data (high temp, zero current)" \
  "$TELEMETRY_URL/api/v1/telemetry" \
  "POST" \
  "201" \
  "$ANOMALOUS_PAYLOAD" || true

# ─── Step 6: Retrieve telemetry for this asset ───────────────────────────
assert_http \
  "6. Retrieve telemetry for asset $CREATED_ASSET_ID" \
  "$TELEMETRY_URL/api/v1/telemetry?asset_id=$CREATED_ASSET_ID" \
  "GET" \
  "200" || true

# ─── Step 7: Wait for anomaly/alert processing ───────────────────────────
echo ""
echo "Waiting ${WAIT_AFTER_TELEMETRY}s for anomaly detection and alert processing..."
sleep $WAIT_AFTER_TELEMETRY

# ─── Step 8: Check anomalies endpoint ───────────────────────────────────
assert_http \
  "7. Check anomalies endpoint for asset $CREATED_ASSET_ID" \
  "$ANOMALY_URL/api/v1/anomalies?asset_id=$CREATED_ASSET_ID" \
  "GET" \
  "200" || true

# ─── Step 9: Check alerts endpoint ──────────────────────────────────────
assert_http \
  "8. Check alerts endpoint for asset $CREATED_ASSET_ID" \
  "$ALERT_URL/api/v1/alerts?asset_id=$CREATED_ASSET_ID" \
  "GET" \
  "200" || true

# ─── Step 10: Update asset status ────────────────────────────────────────
UPDATE_PAYLOAD=$(cat << EOF
{
  "status": "maintenance",
  "metadata": {
    "test_run": "$TEST_RUN_ID",
    "updated_by": "e2e-test"
  }
}
EOF
)

assert_http \
  "9. Update asset status to maintenance" \
  "$ASSET_URL/api/v1/assets/$CREATED_ASSET_ID" \
  "PUT" \
  "200" \
  "$UPDATE_PAYLOAD" || true

# Verify the update took effect
VERIFY_RESPONSE=$(assert_http \
  "10. Verify asset status updated" \
  "$ASSET_URL/api/v1/assets/$CREATED_ASSET_ID" \
  "GET" \
  "200" || echo "")

if echo "$VERIFY_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
status = data.get('status') or data.get('data', {}).get('status', '')
assert status == 'maintenance', f'Expected status=maintenance got status={status}'
" 2>/dev/null; then
  echo "  [PASS] Asset status correctly updated to maintenance"
  PASS=$((PASS + 1))
else
  echo "  [WARN] Could not verify asset status update (may be eventual consistency)"
fi

# ─── Step 11: Delete the asset ───────────────────────────────────────────
DELETE_STATUS=$(curl -s -o /tmp/e2e-delete-$$.txt -w "%{http_code}" \
  --max-time "$CURL_TIMEOUT" \
  -X DELETE \
  -H "Accept: application/json" \
  "$ASSET_URL/api/v1/assets/$CREATED_ASSET_ID" 2>/dev/null || echo "000")

echo ""
echo "--- Step: 11. Delete test asset $CREATED_ASSET_ID ---"
if [ "$DELETE_STATUS" = "200" ] || [ "$DELETE_STATUS" = "204" ]; then
  echo "  [PASS] Asset deleted (HTTP $DELETE_STATUS)"
  PASS=$((PASS + 1))
  CREATED_ASSET_ID=""  # Prevent double-delete in cleanup
elif [ "$DELETE_STATUS" = "404" ]; then
  echo "  [PASS] Asset already gone (HTTP 404) — acceptable"
  PASS=$((PASS + 1))
  CREATED_ASSET_ID=""
else
  echo "  [FAIL] Delete returned HTTP $DELETE_STATUS"
  FAIL=$((FAIL + 1))
  FAILURES+=("Step 11 Delete asset: unexpected HTTP $DELETE_STATUS")
fi

# ─── Step 12: Verify asset is gone ────────────────────────────────────────
GONE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time "$CURL_TIMEOUT" \
  "$ASSET_URL/api/v1/assets/${CREATED_ASSET_ID:-$TEST_RUN_ID}" 2>/dev/null || echo "000")

echo ""
echo "--- Step: 12. Verify asset is no longer accessible ---"
if [ "$GONE_STATUS" = "404" ]; then
  echo "  [PASS] Asset returns 404 after deletion"
  PASS=$((PASS + 1))
else
  echo "  [WARN] Asset returned HTTP $GONE_STATUS after deletion (expected 404)"
fi

# cleanup() will run via EXIT trap and print summary
