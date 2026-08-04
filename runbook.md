# Disaster Recovery Runbook

## Purpose

This runbook outlines the operational steps for recovering the sample Mario API workload and validating the DR process.

## RPO / RTO Targets

- Recovery Point Objective (RPO): 15 minutes
- Recovery Time Objective (RTO): 30 minutes

## Preconditions

- Access to the DR Kubernetes cluster
- Backup artifact available locally or in object storage
- DNS or ingress control available for failover
- Secrets available via environment variables or a secret manager

## Recovery Procedure

1. Verify the backup artifact and required environment variables.
2. Run the backup or restore automation script.
3. Apply the DR-specific overlay and verify rollout status.
4. Execute the health check script against the recovered endpoint.
5. Switch DNS or ingress traffic to the recovered site.
6. Capture the final status and document any issues.

## Operational Notes

- Run the weekly drill workflow to rehearse recovery.
- Capture observability data from Prometheus, Grafana, or the pushgateway to verify post-recovery health.
- Store the encryption key securely and rotate it periodically.
