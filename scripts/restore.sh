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
    echo "Installing LitmusChaos CRDs and operator"
    kubectl get namespace litmus >/dev/null 2>&1 || kubectl create namespace litmus
    kubectl apply -f https://github.com/litmuschaos/litmus/releases/download/3.31.0/litmus-portal-crds.yml
    kubectl apply -f https://github.com/litmuschaos/litmus/releases/download/3.31.0/litmus-installation.yaml
    kubectl wait --for=condition=Available deployment/chaos-operator-ce -n litmus --timeout=120s || true
  fi

  # Ensure the target namespace exists
  kubectl create namespace "$TARGET_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Prefer kustomize overlays if present; render manifests and strip metadata.namespace
  MANIFEST_CONTENT=""
  if [[ -d "$RESTORE_DIR/k8s/overlays/$TARGET_NAMESPACE" ]]; then
    echo "Using overlay: $RESTORE_DIR/k8s/overlays/$TARGET_NAMESPACE"
    MANIFEST_CONTENT=$(kubectl kustomize "$RESTORE_DIR/k8s/overlays/$TARGET_NAMESPACE" 2>/tmp/dr-restore-kustomize.err || true)
    if [[ -z "$MANIFEST_CONTENT" ]]; then
      echo "Overlay render failed, falling back to raw YAML. Reason:"
      sed -n '1,20p' /tmp/dr-restore-kustomize.err
    fi
  fi

  if [[ -z "$MANIFEST_CONTENT" ]] && [[ -d "$RESTORE_DIR/k8s/base" ]]; then
    echo "Using base manifests: $RESTORE_DIR/k8s/base"
    MANIFEST_CONTENT=$(kubectl kustomize "$RESTORE_DIR/k8s/base" 2>/tmp/dr-restore-kustomize.err || true)
    if [[ -z "$MANIFEST_CONTENT" ]]; then
      echo "Base render failed, falling back to raw YAML. Reason:"
      sed -n '1,20p' /tmp/dr-restore-kustomize.err
    fi
  fi

  if [[ -n "$MANIFEST_CONTENT" ]]; then
    echo "Applying rendered manifests into namespace: $TARGET_NAMESPACE"
    # remove any explicit metadata.namespace entries to avoid namespace mismatch
    echo "$MANIFEST_CONTENT" | sed '/^\s*namespace:\s*/d' | kubectl apply -n "$TARGET_NAMESPACE" -f -
  else
    echo "Applying raw manifests into namespace: $TARGET_NAMESPACE"
    find "$RESTORE_DIR/k8s" -type f \( -name '*.yaml' -o -name '*.yml' \) ! -iname 'kustomization.yml' ! -iname 'kustomization.yaml' ! -iname 'Kustomization' | while read -r f; do
      echo "Applying $f -> namespace=$TARGET_NAMESPACE"
      sed '/^\s*namespace:\s*/d' "$f" | kubectl apply -n "$TARGET_NAMESPACE" -f - || true
    done
  fi
  kubectl rollout status deployment/mario-api -n "$TARGET_NAMESPACE" --timeout=90s 2>/dev/null || true
else
  echo "kubectl not available; skipping cluster restore"
fi

echo "Restore completed for ${TARGET_NAMESPACE}"
