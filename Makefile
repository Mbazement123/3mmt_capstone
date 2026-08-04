.PHONY: backup restore health-check chaos monitoring clean

SHELL := /bin/bash

monitoring:
	@echo "Starting local monitoring stack (Prometheus, Grafana, Pushgateway)..."
	docker compose up -d

backup:
	@echo "Executing backup automation..."
	@if [ -f .env ]; then set -a; source .env; set +a; fi && \
	DR_ENC_KEY=$${DR_ENC_KEY:-"default_secret_key"} ./scripts/backup.sh

restore:
	@echo "Executing restore automation..."
	@if [ -f .env ]; then set -a; source .env; set +a; fi && \
	DR_ENC_KEY=$${DR_ENC_KEY:-"default_secret_key"} ./scripts/restore.sh dr-site

health-check:
	@echo "Running health checks..."
	@if [ -f .env ]; then set -a; source .env; set +a; fi && \
	./scripts/health-check.sh http://localhost:5000

chaos:
	@echo "Injecting LitmusChaos pod disruption..."
	kubectl apply -f k8s/base/chaos-engine.yml

clean:
	@echo "Removing generated backup artifacts..."
	rm -f mario-api-config.tar.gz mario-api-config.tar.gz.enc restored-config.tar.gz
	rm -rf /tmp/dr-restore
