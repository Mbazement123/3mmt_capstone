# Project Architecture & Review Report

## 1. Project Overview

This repository is a disaster recovery (DR) runbook and automation starter project centered around a sample Mario API workload.

Its main purpose is to demonstrate how to:
- back up and package deployment-related assets,
- restore them into a disaster recovery environment,
- validate application health after recovery,
- switch traffic to the recovery site,
- monitor recovery status,
- and automate the process through CI/CD.

In practical terms, this is not a full application backend with business logic. It is an operations-oriented project designed to model DR readiness, failover rehearsal, and recovery automation for a containerized service.

### What the project is trying to achieve

- Provide a repeatable DR workflow for a sample service.
- Make recovery steps auditable and scriptable.
- Offer a lightweight platform for learning or demonstrating DR controls.
- Support both local execution and GitHub Actions-based automation.

### Architectural intent

The project combines:
- container orchestration with Kubernetes,
- automation through shell scripts,
- observability with Prometheus and Grafana,
- and workflow automation with GitHub Actions.

---

## 2. File Structure Summary

### Root-level files

- [README.md](README.md): High-level overview of the project and its purpose.
- [runbook.md](runbook.md): The disaster recovery manual and procedural documentation.
- [steps.md](steps.md): Step-by-step execution guidance for using the project.
- [output.md](output.md): This architectural breakdown report.
- [docker-compose.yml](docker-compose.yml): Defines the local monitoring stack.
- [Makefile](Makefile): Simplifies common local commands such as backup, restore, and health checks.
- [.gitignore](.gitignore): Excludes temporary and generated artifacts.

### Kubernetes manifests

- [k8s/base/deployment.yml](k8s/base/deployment.yml): Defines the Mario API deployment resource.
- [k8s/base/service.yml](k8s/base/service.yml): Exposes the deployment internally through a Kubernetes service.
- [k8s/base/chaos-engine.yml](k8s/base/chaos-engine.yml): Defines a LitmusChaos experiment for fault injection.
- [k8s/overlays/primary/kustomization.yml](k8s/overlays/primary/kustomization.yml): Primary-site overlay for scaling and environment-specific values.
- [k8s/overlays/dr-site/kustomization.yml](k8s/overlays/dr-site/kustomization.yml): DR-site overlay for recovery deployment settings.

### Automation scripts

- [scripts/backup.sh](scripts/backup.sh): Packages the Kubernetes assets and config into a backup artifact.
- [scripts/restore.sh](scripts/restore.sh): Restores the artifact and re-applies manifests into the DR environment.
- [scripts/health-check.sh](scripts/health-check.sh): Verifies the restored service is reachable via HTTP.
- [scripts/dns-failover.sh](scripts/dns-failover.sh): Simulates or executes DNS failover to the recovery site.

### Configuration and monitoring

- [config/secrets.template.env](config/secrets.template.env): Template for environment variables and secrets.
- [config/prometheus/prometheus.yml](config/prometheus/prometheus.yml): Prometheus scrape configuration.
- [config/prometheus/alert_rules.yml](config/prometheus/alert_rules.yml): Alert definitions for recovery monitoring.
- [config/grafana/dashboard.json](config/grafana/dashboard.json): Grafana dashboard template for observability.

### GitHub Actions workflows

- [.github/workflows/dr-pipeline.yml](.github/workflows/dr-pipeline.yml): CI/CD workflow for automated DR validation.
- [.github/workflows/dr-drill-schedule.yml](.github/workflows/dr-drill-schedule.yml): Scheduled workflow for recurring recovery drills.

---

## 3. Tech Stack & Tools

This project is primarily infrastructure and automation focused. It uses the following tools and technologies:

### Core platform and runtime

- Bash / shell scripting
- Linux-style automation conventions
- Docker Compose

### Container and orchestration

- Kubernetes
- kubectl
- Kustomize
- LitmusChaos

### Monitoring and observability

- Prometheus
- Grafana
- Pushgateway

### Security and packaging

- OpenSSL for encryption/decryption
- curl for HTTP and API requests

### CI/CD

- GitHub Actions

### Runtime workload

- A container image referenced by the deployment: mbazement123/mario-api:latest

### Databases

- No real database is implemented in this repository.

### Application framework

- No custom application framework is present in this repo.
- The workload is treated as a deployed service rather than as an application source project.

---

## 4. How They Work Together

The system works as a recovery automation pipeline for a sample Mario API service.

### End-to-end lifecycle

1. Environment preparation
   - The operator creates a local environment file from the secrets template.
   - Docker Compose starts the monitoring services.

2. Backup phase
   - The backup script packages the Kubernetes manifests, recovery assets, and config template into an archive.
   - The archive is optionally encrypted using OpenSSL and a supplied key.

3. Restore phase
   - The restore script extracts the backup artifact.
   - It uses kubectl and Kustomize to apply the recovery manifests into the DR namespace.
   - The deployment is brought up through the DR overlay.

4. Validation phase
   - The health check script sends an HTTP request to the restored service.
   - If the service responds successfully, the recovery is considered healthy.

5. Failover phase
   - The DNS failover script changes the endpoint target to the DR site.
   - This simulates or performs traffic redirection to the recovered environment.

6. Monitoring phase
   - Prometheus scrapes metrics from Pushgateway.
   - Grafana visualizes the metrics and dashboards.
   - Alert rules can flag failures or recovery problems.

7. Automation phase
   - GitHub Actions runs the same steps in CI/CD.
   - This enables periodic validation and scheduled DR drills.

### Data flow summary

- The project does not process user-generated business data in the traditional sense.
- Instead, it processes operational data such as:
  - Kubernetes manifest content,
  - backup archive content,
  - environment variables,
  - monitoring metrics,
  - and failover targets.

### Operational flow example

A typical run looks like this:
- prepare secrets,
- start monitoring,
- create backup artifact,
- restore to DR environment,
- verify service health,
- switch DNS traffic,
- and observe the results in Prometheus/Grafana.

---

## 5. Setup & Execution

### Local setup

1. Open the repository directory.
2. Copy the environment template:
   - [config/secrets.template.env](config/secrets.template.env)
3. Start the local observability stack:
   - [docker-compose.yml](docker-compose.yml)
4. Run the backup and restore workflow using the Makefile or scripts.

### Main local execution commands

```bash
cp config/secrets.template.env .env
docker compose up -d
make backup
make restore
make health-check
bash scripts/dns-failover.sh secondary
```

### Component initialization details

#### Docker Compose

Used to start the monitoring stack:
- Prometheus
- Grafana
- Pushgateway

#### Kubernetes

Used to define and apply the workload deployment and DR overlays.

#### Scripts

Used to automate DR operations:
- backup packaging,
- restore deployment,
- health validation,
- and failover routing.

#### GitHub Actions

Used for scheduled or manual automation of the DR workflow.

---

## 6. Architectural Review Notes

### Strengths

- Clear separation between documentation, automation, manifests, and monitoring.
- Good fit for demonstrating DR principles in a lightweight environment.
- Useful for training, demos, and CI/CD validation.
- Easy to extend with real cloud services later.

### Limitations

- This is a starter scaffold, not a full production DR platform.
- The workload is not backed by a real application source codebase.
- The DNS failover is mock-oriented unless real credentials are supplied.
- The backup process is file-based and local rather than integrated with cloud object storage.
- No real database or persistent-state integration is implemented.

### Recommended next steps

To make this project more production-ready, the following would help:
- add a real application service source repository,
- integrate backup storage with a real object store,
- add secrets management instead of local environment files,
- connect Prometheus alerts to incident workflows,
- and add end-to-end tests for restore and failover operations.

---

## 7. Bottom Line

This project is best understood as a practical DR rehearsal framework for a sample Mario API deployment.

It demonstrates how infrastructure, automation, monitoring, and recovery procedures can be combined into a repeatable disaster recovery workflow. While it is currently a lightweight starter implementation, it provides a strong foundation for building a more complete and production-grade DR solution.
