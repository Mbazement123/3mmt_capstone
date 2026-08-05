Azure Terraform provisioning (minimal, cost-conscious)

Overview
- This small Terraform module creates:
  - an Azure resource group
  - a minimal Postgres Single Server (sku `B_Gen5_1`) for low-cost dev testing
  - a firewall rule allowing a single IP/CIDR
  - a database and outputs a `DATABASE_URL`

Important: This is intended for short-lived/dev usage. For production follow Azure best practices (VNET, private endpoints, encryption, backups retention, monitoring).

Prerequisites
- Install Terraform 1.0+
- Install Azure CLI and login (`az login`) or configure a service principal and set the following env vars for automation:
  - `ARM_CLIENT_ID`
  - `ARM_CLIENT_SECRET`
  - `ARM_TENANT_ID`
  - `ARM_SUBSCRIPTION_ID`

GitHub Actions
- There is a workflow at `.github/workflows/terraform-azure-apply.yml` that can run the Terraform provisioning for you.
- Preferred repository secret: `AZURE_CREDENTIALS` — a JSON service principal (same format produced by `az ad sp create-for-rbac --sdk-auth`).
- Alternative: set these individual secrets instead of `AZURE_CREDENTIALS`:
  - `ARM_CLIENT_ID`
  - `ARM_CLIENT_SECRET`
  - `ARM_TENANT_ID`
  - `ARM_SUBSCRIPTION_ID`
- Optional repository secret: `PERSONAL_GITHUB_PAT` — a personal access token with `repo` scope. If provided and the workflow dispatch input `create_github_secret` is set to `true`, the workflow will create/update the repository secret `DATABASE_URL` with the provisioned DB connection string.

Use the workflow via the Actions UI or trigger with `workflow_dispatch` inputs:

- `allowed_ip` — your client IP or CIDR to allow access to the DB (default `0.0.0.0`)
- `location` — Azure region (default `centralus`)
- `create_github_secret` — `true`/`false` to create repository secret automatically (requires `PERSONAL_GITHUB_PAT`)

Quick start
```bash
cd infra/azure
terraform init
terraform apply -var="location=eastus" -var="allowed_ip=YOUR_IP" -auto-approve
# capture the DB URL
terraform output -raw database_url > database_url.txt
```

Wiring to CI / Kubernetes
- Set the `DATABASE_URL` as a GitHub Actions repository secret (use `gh secret set DATABASE_URL < database_url.txt`).
- Or create a Kubernetes Secret using `kubectl create secret generic mario-db --from-literal=DATABASE_URL="$(cat database_url.txt)" -n dr-site`.

Notes on cost
- `B_Gen5_1` is the smallest/cheapest Postgres SKU in this template suitable for dev/testing. Expect ~single-digit USD monthly costs, depending on region. Destroy resources when not needed:
```bash
terraform destroy -auto-approve
```

Security
- Replace `allowed_ip` with your workstation public IP instead of `0.0.0.0` to restrict access.
- Do not commit `database_url.txt` or any credentials to source control.
