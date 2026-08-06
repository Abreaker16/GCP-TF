# GCP — Terraform Module & CI/CD Pipelines

Production-grade, modular Terraform for deploying an application to Google Cloud,
with Cloud Build pipelines for infrastructure delivery and application deployment
across `dev`, `staging`, and `prod`.

## What's included

- **Networking**: one Shared VPC host project (`environments/network-hub`) with a private, non-overlapping subnet per environment, Cloud NAT, flow logs, default-deny firewall — dev/staging/prod attach as Shared VPC service projects instead of each creating their own VPC
- **IAM**: dedicated least-privilege service accounts for the app workload and for CI/CD
- **Compute (pick one per environment)**: GKE, Cloud Run, or Compute Engine (regional MIG + load balancer)
- **Data**: private-IP Cloud SQL (PostgreSQL) with automated backups + PITR
- **Secrets**: Secret Manager with per-secret IAM bindings
- **Storage**: versioned, lifecycle-managed GCS buckets
- **Observability**: log-based metrics, alert policies, notification channels, billing budget alerts
- **CI/CD**: Cloud Build pipelines for `terraform plan/apply` and for build → scan → push → deploy, plus the trigger definitions themselves as Terraform

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design rationale and diagrams.

## Repository layout

```
.
├── modules/                    # Reusable building blocks (no environment logic)
│   ├── shared-vpc-host/        # The ONE VPC + per-env subnets + Shared VPC wiring
│   ├── iam/
│   ├── artifact-registry/
│   ├── secret-manager/
│   ├── cloudsql/
│   ├── storage/
│   ├── monitoring/
│   └── compute/
│       ├── gke/
│       ├── cloud-run/
│       └── compute-engine/
├── environments/                # One folder per deployable root; own state + tfvars
│   ├── network-hub/             # Shared VPC HOST project — apply this FIRST, once
│   ├── dev/                     # Shared VPC service project — its own branch/state
│   ├── staging/                 # Shared VPC service project — its own branch/state
│   └── prod/                    # Shared VPC service project — its own branch/state
├── pipelines/
│   └── cloudbuild/
│       ├── cloudbuild-infra.yaml
│       ├── cloudbuild-app-gke.yaml
│       ├── cloudbuild-app-cloudrun.yaml
│       ├── cloudbuild-app-compute.yaml
│       └── triggers.tf          # Cloud Build triggers, managed as code
├── scripts/
│   └── bootstrap.sh             # One-time: enable APIs, create state bucket
└── docs/
    └── ARCHITECTURE.md
```

## Prerequisites

- Terraform >= 1.7
- `gcloud` CLI authenticated with an account that has `roles/owner` (or equivalent) on each target GCP project, for the one-time bootstrap
- A billing account linked to each project
- A GitHub repository containing this code, connected to Cloud Build (2nd-gen) — see below

## Shared VPC: four projects, one network

All three environments share a **single VPC**, owned by a dedicated networking
project (`network-hub`) that never runs application workloads:

```
my-gcp-project-net-host   (Shared VPC HOST — VPC + one subnet per env, NAT, firewall)
   ├── attaches → my-gcp-project-dev      (service project — dev subnet 10.10.0.0/20)
   ├── attaches → my-gcp-project-staging  (service project — staging subnet 10.11.0.0/20)
   └── attaches → my-gcp-project-prod     (service project — prod subnet 10.12.0.0/20)
```

Each environment still gets its own GCP project, its own Terraform state, its
own branch, and its own non-overlapping CIDR — so dev/staging/prod remain
isolated from each other (firewall rules scope `allow-internal` to each
subnet's own range) — but they route through one Cloud NAT, one set of
Cloud Router/NAT egress IPs, and one place (`modules/shared-vpc-host`) to
manage firewall/subnet/peering changes instead of three.

## Getting started

**Step 0 — Shared VPC host, once, before anything else:**
```bash
./scripts/bootstrap.sh my-gcp-project-net-host network-hub us-central1
cd environments/network-hub
# edit terraform.tfvars: host_project_id, environment_subnets CIDRs, service_projects
# edit backend.tf to point at the state bucket created above
terraform init
terraform apply -var-file=terraform.tfvars
```
This creates the VPC, the dev/staging/prod subnets, Cloud NAT, baseline
firewall rules, the Cloud SQL private-services peering (created once for the
whole VPC), attaches dev/staging/prod as Shared VPC service projects, and
grants each environment's future service accounts `roles/compute.networkUser`
scoped to *only their own subnet*.

**Then, per environment (dev/staging/prod):**

1. **Bootstrap the service project** (enables APIs, creates its Terraform state bucket):
   ```bash
   ./scripts/bootstrap.sh <project_id> dev us-central1
   ```

2. **Configure the environment**:
   ```bash
   cd environments/dev
   # edit terraform.tfvars: project_id, host_project_id, notification_email, compute_platform, etc.
   ```
   Edit `backend.tf` in the same folder to point `bucket` at the state bucket created in step 1.
   `host_project_id` must match the project you used for `network-hub`.

3. **Initialize and apply**:
   ```bash
   terraform init
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```

4. Repeat for `staging` and `prod` (each is its own project + state file, but all three read the same shared VPC).

## Wiring up CI/CD (one branch per environment)

Each environment deploys from its own long-lived Git branch:

| Branch    | Environment | Behavior on push                                   |
|-----------|-------------|-----------------------------------------------------|
| `develop` | dev         | auto: `terraform apply` + app build & deploy         |
| `staging` | staging     | auto: `terraform apply` + app build & deploy         |
| `main`    | prod        | **manual approval required**, then apply + deploy    |

Steps:

1. Create the three branches in your GitHub repo if they don't exist yet: `develop`, `staging`, `main`.
2. In the Cloud Console, go to **Cloud Build > Repositories** and connect the repository (2nd-gen connection). Note the connection name.
3. Update `pipelines/cloudbuild/triggers.tf`:
   - Set `repo_owner`, `repo_name`, `github_connection_name`.
   - Adjust the `environments` map if your branch names, app name, or per-environment compute platform (`app_pipeline: "gke" | "cloudrun" | "compute"`) differ from the defaults.
4. Apply the triggers (from a bootstrap/admin context, since it needs the repository connection):
   ```bash
   cd pipelines/cloudbuild
   terraform init
   terraform apply \
     -var="project_id=<project_id>" \
     -var="repo_owner=<owner>" \
     -var="repo_name=<repo>"
   ```
5. From then on:
   - A PR opened against `develop`, `staging`, or `main` triggers a **plan-only** run against that environment, so reviewers see the infra diff before merge.
   - Pushing to `develop` applies dev infra and deploys the app to dev — fully automatic.
   - Pushing to `staging` applies staging infra and deploys the app to staging — fully automatic.
   - Pushing to `main` requires **manual approval** in the Cloud Build console (or `gcloud builds approve`) before the prod apply and deploy run. The prod app deploy uses canary + smoke test + traffic promotion.

Recommended team workflow: merge feature branches into `develop` → promote `develop` into `staging` via PR → promote `staging` into `main` via PR. Add GitHub branch protection rules if you want to enforce that promotion order (e.g. only allow `main` to receive merges from `staging`).

## Choosing a compute platform

Set `compute_platform` in an environment's `terraform.tfvars` to `"gke"`, `"cloud_run"`, or `"compute_engine"`. Only the selected platform's resources are created; networking, IAM, database, secrets, and monitoring are shared across all three. See `pipelines/cloudbuild/cloudbuild-app-<platform>.yaml` for the matching deployment pipeline, and update the trigger's `filename` in `triggers.tf` to match.

## Security notes

- No service account keys are created or downloaded; Cloud Build and Workload Identity use short-lived, keyless credentials.
- Cloud SQL has no public IP and requires SSL.
- Default firewall posture is deny-all ingress; only explicit rules (internal traffic, health checks, IAP-tunneled SSH) are allowed.
- `prod` environment applies require a tagged release and manual approval in Cloud Build.
- Review and tighten `authorized_ip_ranges` and `authorized_master_cidrs` before using in a real environment — the examples are placeholders.

## Customizing

This is a starting point, not a black box — before using in a real environment:
- Review machine sizes, autoscaling bounds, and retention/lifecycle settings against your actual traffic and compliance requirements.
- Add a managed SSL certificate + HTTPS listener to the Compute Engine module if you need TLS termination there (an HTTP-only listener is wired up by default).
- Add a WAF / Cloud Armor policy in front of any internet-facing load balancer if the app is public.
- Wire real budget/billing account IDs and alerting channels (Slack, PagerDuty) for prod.
