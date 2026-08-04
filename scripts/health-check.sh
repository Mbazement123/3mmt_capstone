#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST=${1:-"http://localhost:8080"}

HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "${TARGET_HOST}/")
if [[ "$HTTP_STATUS" == "200" ]]; then
  echo "SUCCESS: Mario API responded with status 200 OK"
  exit 0
fi

echo "FAILURE: Mario API returned status $HTTP_STATUS"
exit 1
