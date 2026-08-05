#!/usr/bin/env bash
set -euo pipefail

TARGET_NAMESPACE=${1:-"dr-site"}
BACKUP_FILE="mario-api-config.tar.gz.enc"
ARCHIVE_FILE="mario-api-config.tar.gz"
RESTORE_DIR="/tmp/dr-restore"

if [[ -f "$BACKUP_FILE" ]]; then
  SOURCE_FILE="$BACKUP_FILE"
elif [[ -f "$ARCHIVE_FILE" ]]; then
  SOURCE_FILE="$ARCHIVE_FILE"
else
  echo "Error: no backup artifact found"
  exit 1
fi

mkdir -p "$RESTORE_DIR"

if [[ "$SOURCE_FILE" == *.enc ]]; then
  if [[ -z "${DR_ENC_KEY:-}" ]]; then
    echo "Error: DR_ENC_KEY is required for encrypted backups"
    exit 1
  fi
  openssl enc -d -aes-256-cbc -pbkdf2 -in "$SOURCE_FILE" -out "$ARCHIVE_FILE" -k "$DR_ENC_KEY"
elif [[ "$SOURCE_FILE" == "$ARCHIVE_FILE" ]]; then
  echo "Restore archive already present; skipping copy."
else
  cp "$SOURCE_FILE" "$ARCHIVE_FILE"
fi

tar -xzf "$ARCHIVE_FILE" -C "$RESTORE_DIR"

if command -v kubectl >/dev/null 2>&1; then
  if ! kubectl get crd chaosengines.litmuschaos.io >/dev/null 2>&1; then
    echo "Installing LitmusChaos CRDs"
    kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v1.13.0.yaml
    kubectl wait --for=condition=Available deployment/litmus-operator -n litmus --timeout=120s || true
  fi

  kubectl create namespace "$TARGET_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -k "$RESTORE_DIR/k8s/overlays/${TARGET_NAMESPACE}" -n "$TARGET_NAMESPACE" 2>/dev/null || kubectl apply -f "$RESTORE_DIR/k8s/base" -n "$TARGET_NAMESPACE"
  kubectl rollout status deployment/mario-api -n "$TARGET_NAMESPACE" --timeout=90s 2>/dev/null || true
else
  echo "kubectl not available; skipping cluster restore"
fi

echo "Restore completed for ${TARGET_NAMESPACE}"
