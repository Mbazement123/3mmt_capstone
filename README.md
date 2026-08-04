# DR Runbook & Automation

This repository implements a lightweight disaster recovery (DR) starter project for a sample application workload. It combines a recovery runbook, Kubernetes manifests, backup and restore automation, monitoring placeholders, and GitHub Actions workflows for DR rehearsal.

## What this project includes

- A recovery playbook in [runbook.md](runbook.md)
- Kubernetes deployment and overlay manifests in [k8s](k8s)
- Backup, restore, and DNS failover automation in [scripts](scripts)
- Local observability support via [docker-compose.yml](docker-compose.yml)
- CI/CD validation workflows in [.github/workflows](.github/workflows)

## Project structure

- [k8s/base](k8s/base) - shared deployment, service, and chaos manifests
- [k8s/overlays/primary](k8s/overlays/primary) - primary-site override values
- [k8s/overlays/dr-site](k8s/overlays/dr-site) - disaster-recovery override values
- [scripts](scripts) - operational automation for backup, restore, health checks, and failover
- [config](config) - Prometheus, Grafana, and secret templates
- [.github/workflows](.github/workflows) - scheduled validation and drill workflows

## Quick start

1. Review the recovery steps in [runbook.md](runbook.md)
2. Copy the secret template and populate it:
   - `cp config/secrets.template.env .env`
   - edit `.env` and replace placeholder values with your actual secrets and endpoints
   - the Makefile will automatically load `.env` values for backup, restore, and health-check targets
3. Start the local observability stack:
   - `docker compose up -d`
4. Run the automation flow:
   - `make backup`
   - `make restore`
   - `make health-check`
5. Trigger the GitHub Actions workflows for scheduled DR validation

## Operational goals

- Keep the workload recoverable with a documented RPO and RTO
- Provide a repeatable restore path for a DR drill
- Make failover and validation steps easy to automate in CI/CD

## Notes

The implementation is intentionally practical and extensible. It is suitable as a starting point for a DR rehearsal environment and can be expanded with real cloud integrations, secrets management, and production-grade IaC.

  appinfo:
    appns: 'default'
    applabel: 'app=mario-api'
    appkind: 'deployment'
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: '30'
            - name: CHAOS_INTERVAL
              value: '10'
            - name: FORCE
              value: 'true'
```

# Scripts & Automation Hooks
## Packaging & Backup Script (scripts/backup.sh)

``` bash
#!/usr/bin/env bash
set -e

TARGET_NAMESPACE=${1:-"dr-site"}

echo "==> Decrypting Mario API Configurations..."
openssl enc -d -aes-256-cbc \
  -in mario-api-config.tar.gz.enc \
  -out restored-config.tar.gz \
  -k "${DR_ENC_KEY}" -pbkdf2

tar -xzf restored-config.tar.gz -C /tmp/

echo "==> Applying Manifests to DR Kubernetes Cluster..."
kubectl create namespace "$TARGET_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k /tmp/k8s/overlays/dr-site -n "$TARGET_NAMESPACE"

echo "==> Waiting for Mario API Deployment Rollout..."
kubectl rollout status deployment/mario-api -n "$TARGET_NAMESPACE" --timeout=90s
```
## k8s/base/service.yml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mario-api-service
  labels:
    app: mario-api
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
  selector:
    app: mario-api
```
## k8s/overlays/primary/kustomization.yml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: primary

resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: mario-api
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```
## k8s/overlays/dr-site/kustomization.yml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dr-site

resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: mario-api
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
```
## scripts/restore.sh
```bash
#!/usr/bin/env bash
set -e

TARGET_NAMESPACE=${1:-"dr-site"}
BACKUP_FILE="mario-api-config.tar.gz.enc"

echo "==> Starting Mario API DR Restoration..."

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Encrypted backup file '$BACKUP_FILE' not found!"
  exit 1
fi

echo "==> Decrypting configuration artifacts..."
openssl enc -d -aes-256-cbc \
  -in "$BACKUP_FILE" \
  -out restored-config.tar.gz \
  -k "${DR_ENC_KEY}" -pbkdf2

mkdir -p /tmp/dr-restore
tar -xzf restored-config.tar.gz -C /tmp/dr-restore

echo "==> Creating namespace: ${TARGET_NAMESPACE}..."
kubectl create namespace "$TARGET_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying Kustomize overlays for [${TARGET_NAMESPACE}]..."
if [ -d "/tmp/dr-restore/k8s/overlays/${TARGET_NAMESPACE}" ]; then
  kubectl apply -k "/tmp/dr-restore/k8s/overlays/${TARGET_NAMESPACE}" -n "$TARGET_NAMESPACE"
else
  echo "Overlay for ${TARGET_NAMESPACE} not found. Applying base manifests..."
  kubectl apply -f /tmp/dr-restore/k8s/base/ -n "$TARGET_NAMESPACE"
fi

echo "==> Waiting for Mario API deployment to become ready..."
kubectl rollout status deployment/mario-api -n "$TARGET_NAMESPACE" --timeout=90s

echo "==> Restoration complete! Workload active in namespace: ${TARGET_NAMESPACE}"
```
### scripts/dns-failover.sh
```bash
#!/usr/bin/env bash
set -e

TARGET_REGION=${1:-"secondary"}

echo "==> Initiating DNS Failover Switch to [${TARGET_REGION}] region..."

if [ "$TARGET_REGION" == "secondary" ] || [ "$TARGET_REGION" == "dr" ]; then
  TARGET_IP=${DR_SITE_INGRESS_IP:-"198.51.100.20"}
else
  TARGET_IP=${PRIMARY_SITE_INGRESS_IP:-"198.51.100.10"}
fi

echo "==> Simulating DNS failover to point to: ${TARGET_IP}"
echo "[MOCK MODE] mario.yourdomain.com -> ${TARGET_IP}"
```

## Health Check Script (scripts/health-check.sh)

``` bash
#!/usr/bin/env bash
set -e

TARGET_HOST=${1:-"http://localhost:8080"}

echo "==> Running Post-Recovery Sanity Check against ${TARGET_HOST}..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "${TARGET_HOST}/")

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "SUCCESS: Mario API responded with status 200 OK."
  exit 0
else
  echo "FAILURE: Mario API returned status $HTTP_STATUS."
  exit 1
fi
```
# GitHub Actions CI/CD Pipeline
## DR Execution Workflow (.github/workflows/dr-pipeline.yml)

```yaml
name: "DR Pipeline: Mario API Backup & K8s Failover Validation"

on:
  schedule:
    - cron: '0 0 * * *' # Scheduled daily verification
  workflow_dispatch: # Manual execution

jobs:
  validate-dr-environment:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Set up Kubernetes (Kind)
        uses: helm/kind-action@v1.8.0
        with:
          cluster_name: dr-secondary-cluster

      - name: Spin up Monitoring Pushgateway
        run: docker compose up -d pushgateway

      - name: Execute Backup Automation Script
        env:
          DR_ENC_KEY: ${{ secrets.DR_ENC_KEY }}
        run: |
          chmod +x ./scripts/*.sh
          ./scripts/backup.sh
          echo "BACKUP_SIZE=$(stat -c%s mario-api-config.tar.gz.enc)" >> $GITHUB_ENV

      - name: Run Restore Runner
        env:
          DR_ENC_KEY: ${{ secrets.DR_ENC_KEY }}
        run: |
          ./scripts/restore.sh dr-site

      - name: Execute Health Checks
        run: |
          kubectl port-forward svc/mario-api-service 8080:80 -n dr-site &
          sleep 5
          ./scripts/health-check.sh http://localhost:8080

      - name: Emit RTO / Health Metrics
        if: always()
        run: |
          STATUS=${{ job.status == 'success' && 1 || 0 }}
          echo "dr_backup_success_status $STATUS" > metrics.txt
          echo "dr_backup_size_bytes ${{ env.BACKUP_SIZE }}" >> metrics.txt
          curl --data-binary @metrics.txt http://localhost:9091/metrics/job/dr_mario_api_automation
```
## .github/workflows/dr-drill-schedule.yml
### This workflow runs automated periodic disaster recovery drills (e.g., every Sunday at midnight) to verify that your DR site can be restored and pass health checks without manual intervention.
```yaml
name: "Scheduled DR Drill & Verification"

on:
  schedule:
    - cron: '0 0 * * 0' # Weekly on Sunday at 00:00 UTC
  workflow_dispatch:     # Allows manually triggering a drill

jobs:
  dr-drill:
    name: "Run Automated DR Drill"
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Set up Kubernetes (Kind Cluster for DR Drill)
        uses: helm/kind-action@v1.8.0
        with:
          cluster_name: dr-drill-cluster

      - name: Decrypt & Restore Mario API to DR Overlays
        env:
          DR_ENC_KEY: ${{ secrets.DR_ENC_KEY }}
        run: |
          chmod +x ./scripts/*.sh
          ./scripts/backup.sh
          ./scripts/restore.sh dr-site

      - name: Run Post-Recovery Health Checks
        run: |
          kubectl port-forward svc/mario-api-service 8080:80 -n dr-site &
          sleep 5
          ./scripts/health-check.sh http://localhost:8080

      - name: Report Drill Status
        if: always()
        run: |
          if [ "${{ job.status }}" == "success" ]; then
            echo "DR Drill PASSED: Mario API successfully deployed and responding in DR environment."
          else
            echo "DR Drill FAILED: Disaster recovery validation encountered errors."
            exit 1
          fi
```

# Unified Control (Makefile)

```MakeFile
.PHONY: build backup restore health-check chaos monitoring clean

SHELL := /bin/bash

monitoring:
	@echo "Starting local monitoring stack (Prometheus, Grafana, Pushgateway)..."
	docker compose up -d

backup:
	@echo "Executing backup script..."
	DR_ENC_KEY=$${DR_ENC_KEY:-"default_secret_key"} ./scripts/backup.sh

restore:
	@echo "Executing restore script..."
	DR_ENC_KEY=$${DR_ENC_KEY:-"default_secret_key"} ./scripts/restore.sh dr-site

health-check:
	@echo "Running health checks..."
	./scripts/health-check.sh http://localhost:8080

chaos:
	@echo "Injecting LitmusChaos pod disruption..."
	kubectl apply -f k8s/base/chaos-engine.yml

clean:
	docker compose down -v
	rm -f *.tar.gz *.tar.gz.enc
```
# Observability Specs (config/)
## config/prometheus/prometheus.yml
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - 'alert.rules.yml'

scrape_configs:
  - job_name: 'pushgateway'
    static_configs:
      - targets: ['pushgateway:9091']

  - job_name: 'mario-api-primary'
    static_configs:
      - targets: ['mario-api.primary.svc.cluster.local:80']

  - job_name: 'mario-api-dr'
    static_configs:
      - targets: ['mario-api.dr-site.svc.cluster.local:80']
```
## config/prometheus/alert.rules.yml
```yaml
groups:
  - name: DisasterRecoveryAlerts
    rules:
      - alert: MarioAPIDownPrimary
        expr: probe_success{job="mario-api-primary"} == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Primary Mario API Unavailable"
          description: "The Mario API endpoint in the primary region is unreachable."

      - alert: DRBackupPipelineFailed
        expr: dr_backup_success_status == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "DR Drill/Backup Failed"
          description: "Automated recovery execution returned status 0."

      - alert: RTOThresholdBreached
        expr: dr_restore_duration_seconds > 120
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Recovery Time Exceeded 2 Minutes"
          description: "Mario API cluster restoration duration was {{ $value }}s."
```
## config/grafana/dashboard-template.json
```JSON
{
  "annotations": { "list": [] },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "title": "Disaster Recovery Metrics & RTO/RPO Dashboard",
  "panels": [
    {
      "title": "DR Pipeline Status (1 = Healthy, 0 = Failed)",
      "type": "stat",
      "targets": [
        {
          "expr": "dr_backup_success_status",
          "refId": "A"
        }
      ],
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 }
    },
    {
      "title": "Backup Payload Size (Bytes)",
      "type": "stat",
      "targets": [
        {
          "expr": "dr_backup_size_bytes",
          "refId": "B"
        }
      ],
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 }
    }
  ],
  "schemaVersion": 38,
  "version": 1
}
```
config/secrets.template.env
```code snipet
# Encryption keys for DR backups and OpenSSL tarballs
DR_ENC_KEY=replace_with_strong_aes256_passphrase

# Target IP Endpoints
PRIMARY_SITE_INGRESS_IP=198.51.100.10
DR_SITE_INGRESS_IP=198.51.100.20
DR_SITE_INGRESS_IP=198.51.100.20
```
