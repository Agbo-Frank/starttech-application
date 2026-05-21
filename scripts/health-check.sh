#!/usr/bin/env bash
# Poll the backend /ping endpoint until it returns a healthy response.
# Usage: ./scripts/health-check.sh <alb-dns-name> [max-retries]
# Requires: curl

set -euo pipefail

ALB_DNS="${1:-${ALB_DNS_NAME:?Usage: health-check.sh <alb-dns-name> [max-retries]}}"
MAX_RETRIES="${2:-20}"
SLEEP_SECONDS=15

echo "=== Health Check: http://$ALB_DNS/ping ==="
echo "Max retries: $MAX_RETRIES, interval: ${SLEEP_SECONDS}s"
echo ""

for i in $(seq 1 "$MAX_RETRIES"); do
  echo "Attempt $i/$MAX_RETRIES..."
  RESPONSE=$(curl -sf --max-time 10 "http://$ALB_DNS/ping" 2>/dev/null || true)
  if echo "$RESPONSE" | grep -qi "pong"; then
    echo "Health check PASSED: $RESPONSE"
    exit 0
  fi
  echo "Not ready yet (response: '${RESPONSE:-no response}')"
  if [[ $i -lt $MAX_RETRIES ]]; then
    sleep "$SLEEP_SECONDS"
  fi
done

echo ""
echo "Health check FAILED after $MAX_RETRIES attempts."
exit 1
