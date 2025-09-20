# Nomad on GCP (Terraform)

This repository provisions a secure, scalable HashiCorp Nomad cluster on Google Cloud using Terraform. It includes:

- Nomad server (1x) and scalable Nomad clients (Managed Instance Group)
- Private networking (no public IPs), SSH only via Google IAP
- Secure Nomad UI (binds to localhost; access via IAP/SSH tunnel)
- Sample Nomad job (hello-world web app)
- Google Ops Agent for logs and metrics (basic observability)
- Optional CI workflow for Terraform validation

## Architecture

- VPC `nomad-vpc` with a single private subnet
- Firewall rules:
  - Internal allow within subnet for Nomad ports (4646/4647/4648) and app (8080)
  - SSH only from Google IAP (35.235.240.0/20)
- Nomad server has a static internal IP so clients can reliably join
- Clients are created via a regional Managed Instance Group; scale via `var.client_count`
- Nomad UI enables on server but binds to `127.0.0.1` (must use IAP/SSH tunnel)
- Instances run with a service account that can publish logs/metrics only
- Required Google APIs (Compute, IAM, IAP, Logging, Monitoring) are enabled automatically by Terraform

## Prerequisites

- gcloud SDK installed and authenticated: `gcloud auth login`
- A GCP project with billing enabled
- Terraform >= 1.5
- Your user has these roles on the project:
  - Owner or the combination of: Compute Admin, Service Account Admin, IAP Secured Tunnel User, Project IAM Admin

## Files

- `versions.tf` provider definitions
- `variables.tf` configurable inputs
- `main.tf` project metadata (OS Login)
- `network.tf` VPC, subnet, firewall
- `iam.tf` service account and IAM bindings
- `compute.tf` server instance, client template + MIG
- `scripts/server-startup.sh` installs and configures Nomad server
- `scripts/client-startup.sh` installs and configures Nomad client
- `jobs/hello-world.nomad.hcl` sample Nomad job

## Inputs: where to set GCP values

You must set the following variables:

- `project_id` (required)
- `region` (default `asia-south1`)
- `zone` (default `asia-south1-a`)

Set via one of:

- `terraform.tfvars` file
- `-var` flags on the command line
- Environment variables `TF_VAR_project_id`, etc.

Example `terraform.tfvars`:

```hcl
project_id = "city-428608"
region     = "asia-south1"
zone       = "asia-south1-a"
client_count = 2
```

No GCP keys are stored in code. Authentication flows from your gcloud credentials. If you must use a service account key, export `GOOGLE_APPLICATION_CREDENTIALS` to the JSON file before running Terraform; not recommended.

## Deploy

```bash
# Initialize
terraform init

# Review plan
terraform plan -var project_id=YOUR_GCP_PROJECT_ID

# Apply
terraform apply -auto-approve -var project_id=YOUR_GCP_PROJECT_ID
```

## Access Nomad UI (secure)

The UI listens only on localhost of the server. Use IAP SSH tunneling from your workstation (requires IAP access in your org and your IAM to include IAP Secured Tunnel User):

```bash
# Set helpful vars
PROJECT_ID=YOUR_GCP_PROJECT_ID
ZONE=YOUR_ZONE            # e.g., asia-south1-a
SERVER_NAME=$(terraform output -raw server_name)

# Port-forward Nomad UI 4646 to your local 4646
gcloud compute ssh "$SERVER_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --tunnel-through-iap \
  -- -L 4646:localhost:4646
```

Then open http://localhost:4646 in your browser.

## Deploy the sample app

SSH to the server via IAP and submit the job to Nomad:

```bash
# Copy the job file to the server using IAP
gcloud compute scp jobs/hello-world.nomad.hcl "$SERVER_NAME":/tmp/hello-world.nomad.hcl \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --tunnel-through-iap

# SSH to the server and run the job
gcloud compute ssh "$SERVER_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --tunnel-through-iap --command 'sudo nomad job run /tmp/hello-world.nomad.hcl'
```

Alternatively, copy the job file and run `nomad job run`.

### Access the sample app

The job binds to host port 8080 on a client node. To access it from your workstation, create a tunnel to any client instance (replace `CLIENT_INSTANCE_NAME` with the actual one from the MIG):

```bash
# List clients in your zone and pick one name
gcloud compute instances list \
  --filter="name~'nomad-client' AND zone:($ZONE)" \
  --project "$PROJECT_ID"

CLIENT_INSTANCE_NAME=REPLACE_WITH_CLIENT_NAME

# Tunnel port 8080
gcloud compute ssh "$CLIENT_INSTANCE_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --tunnel-through-iap \
  -- -L 8080:localhost:8080

# Then open http://localhost:8080
```

## Scaling clients

Change `client_count` in your variables (e.g., `terraform.tfvars`) and run `terraform apply`. The MIG will scale accordingly.

## Security Notes

- No public IPs are assigned. All access is via IAP.
- Nomad UI is bound to localhost only.
- OS Login enabled for auditable SSH access.
- Service account has minimal roles for telemetry.
- For production, consider enabling Nomad ACLs and TLS between nodes.
  - To enable ACLs, add `acl { enabled = true }` to both server and client configs and securely provision tokens (e.g., via secrets manager).

## CI (optional)

A basic GitHub Actions workflow is provided in `.github/workflows/terraform-ci.yml` to run `terraform fmt` and `validate` on PRs.
