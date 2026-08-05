#!/usr/bin/env bash
set -euo pipefail

TARGET_NAMESPACE=${1:-"dr-site"}
ARCHIVE_NAME="mario-api-config.tar.gz"
ENCRYPTED_ARCHIVE="${ARCHIVE_NAME}.enc"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/k8s/base" "$WORKDIR/k8s/overlays/primary" "$WORKDIR/k8s/overlays/dr-site" "$WORKDIR/config"
cp -R k8s/. "$WORKDIR/k8s/"
cp config/secrets.template.env "$WORKDIR/config/"

tar -czf "$ARCHIVE_NAME" -C "$WORKDIR" .

if [[ -n "${DR_ENC_KEY:-}" ]]; then
  openssl enc -aes-256-cbc -salt -pbkdf2 -in "$ARCHIVE_NAME" -out "$ENCRYPTED_ARCHIVE" -k "$DR_ENC_KEY"
  rm -f "$ARCHIVE_NAME"
  echo "Backup artifact written to ${ENCRYPTED_ARCHIVE}"
else
  echo "No DR_ENC_KEY provided; created unencrypted archive ${ARCHIVE_NAME}"
fi

echo "Backup completed for namespace ${TARGET_NAMESPACE}"
