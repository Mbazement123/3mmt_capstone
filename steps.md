# Step-by-Step Guide for the Mario API DR Project

Yes — this project is about a Mario API workload, and it is set up as a disaster recovery (DR) runbook and automation starter.

The goal is to show how to back up, restore, validate, and fail over a sample Mario API deployment in a structured way.

## Step 1: Open the project folder

Run:

```bash
cd "c:\Users\PALMPAY\Documents\Project\3mmt  capstone"
```

## Step 2: Install the required tools

Make sure you have:

- Docker Desktop or Docker Engine
- Bash
- kubectl (optional but recommended)
- OpenSSL
- curl
- Git

## Step 3: Create your environment file

Copy the example secret file:

```bash
cp config/secrets.template.env .env
```

Then edit the file and replace the placeholder values with your real values.

Example:

```bash
DR_ENC_KEY=your-secure-key
PRIMARY_SITE_INGRESS_IP=198.51.100.10
DR_SITE_INGRESS_IP=198.51.100.20
```

The Makefile will automatically source `.env` when you run the backup, restore, and health-check targets.

## Step 4: Start the monitoring stack with Docker Compose

Use the file [docker-compose.yml](docker-compose.yml) to start Prometheus, Grafana, and Pushgateway:

```bash
docker compose up -d
```

You can then open:

- Prometheus at http://localhost:9090
- Grafana at http://localhost:3000
- Pushgateway at http://localhost:9091

## Step 5: Review the project folders

Each folder has a purpose:

- [k8s](k8s): Kubernetes deployment files for the Mario API
- [scripts](scripts): backup, restore, health check, and failover automation
- [config](config): monitoring and secret templates
- [.github/workflows](.github/workflows): CI/CD workflows for DR validation

## Step 6: Run the backup process

Create a backup artifact for the workload:

```bash
make backup
```

This runs [scripts/backup.sh](scripts/backup.sh) and packages the deployment and config files.

## Step 7: Run the restore process

Restore the workload into the DR flow:

```bash
make restore
```

This runs [scripts/restore.sh](scripts/restore.sh) and applies the DR-oriented restore logic.

## Step 8: Run the health check

Verify that the application is responding:

```bash
make health-check
```

This uses [scripts/health-check.sh](scripts/health-check.sh) to confirm the Mario API is reachable on the local Compose service port.

## Step 9: Simulate DNS failover

If you want to test the failover logic:

```bash
bash scripts/dns-failover.sh secondary
```

This uses the DNS settings from your environment file and simulates traffic redirection to the DR site.

## Step 10: Test Kubernetes deployment manually (optional)

If you have a cluster available, you can apply the manifests directly:

```bash
kubectl apply -f k8s/base
kubectl apply -k k8s/overlays/dr-site
```

This shows how the Mario API deployment would be moved or restored in a real cluster.

## Step 11: Clean up when finished

Remove the generated artifact files:

```bash
make clean
```

## Step 12: Optional review

Confirm the restored service and any DR validation logs after cleanup.

Remove the generated artifact files:

```bash
make clean
```

## Step 13: Use the GitHub workflows (optional)

You can also trigger the automation from GitHub Actions:

- [.github/workflows/dr-pipeline.yml](.github/workflows/dr-pipeline.yml)
- [.github/workflows/dr-drill-schedule.yml](.github/workflows/dr-drill-schedule.yml)

These workflows automate backup, restore, and validation for the Mario API DR process.

## What success looks like

When everything works correctly, you should see:

- Docker Compose running the monitoring stack
- a backup artifact created successfully
- the restore script completing
- the health check returning success
- DNS failover output being generated
