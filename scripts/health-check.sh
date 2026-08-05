#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/health-check.sh http://localhost:8080/api
# Defaults to http://localhost:8080/api if no argument provided.

TARGET_HOST=${1:-"http://localhost:8080/api"}
RETRIES=${2:-5}
SLEEP_SECONDS=${3:-3}

echo "Running health check against ${TARGET_HOST} (retries=${RETRIES})"

for attempt in $(seq 1 "$RETRIES"); do
  HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "${TARGET_HOST}" || echo "000")
  if [[ "$HTTP_STATUS" == "200" ]]; then
    echo "SUCCESS: Mario API responded with status 200 OK"
    exit 0
  fi
  echo "Attempt ${attempt}/${RETRIES} - got HTTP status ${HTTP_STATUS}; retrying in ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo "FAILURE: Mario API returned status ${HTTP_STATUS} after ${RETRIES} attempts"
exit 1
