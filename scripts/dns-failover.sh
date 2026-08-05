#!/usr/bin/env bash
set -euo pipefail

TARGET_REGION=${1:-"secondary"}

if [[ "$TARGET_REGION" == "secondary" || "$TARGET_REGION" == "dr" ]]; then
  TARGET_IP=${DR_SITE_INGRESS_IP:-"198.51.100.20"}
else
  TARGET_IP=${PRIMARY_SITE_INGRESS_IP:-"198.51.100.10"}
fi

echo "==> Simulating DNS failover to ${TARGET_IP}"
echo "[MOCK MODE] mario.yourdomain.com -> ${TARGET_IP}"
