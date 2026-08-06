# Architecture Overview

## Design Principles

- **Environment isolation, shared network**: `dev`, `staging`, and `prod` are separate GCP projects, each with its own Terraform state file (GCS backend) and its own `terraform.tfvars` — no shared *state*, no application-resource blast radius across environments. Networking is the deliberate exception: all three attach as Shared VPC service projects to a single VPC owned by a dedicated `network-hub` host project, so they share one Cloud NAT/router and one firewall/subnet source of truth instead of three. Each environment still gets its own non-overlapping subnet/CIDR and firewall rules that scope internal traffic to that subnet only, so dev/staging/prod remain L3-isolated from each other despite sharing the VPC.
- **Reusable modules, thin environments**: all resource logic lives in `modules/*`; each `environments/<env>/main.tf` only composes modules and sets environment-specific values. `environments/network-hub` is the one exception that owns real infrastructure (the shared VPC) rather than reading it.
- **Least privilege IAM**: two service accounts per environment — one for the running application workload, one for CI/CD — each scoped to only the roles it needs, never `roles/editor` or `roles/owner`.
- **Private by default**: Cloud SQL has no public IP; GKE nodes and Cloud Run egress live on private VPC ranges; Cloud NAT provides controlled internet egress; firewall default-denies ingress.
- **Compute platform is a variable, not a fork**: `compute_platform = "gke" | "cloud_run" | "compute_engine"` in each environment's tfvars selects which compute module gets instantiated via `count`. Networking, IAM, database, secrets, and monitoring are identical regardless of platform choice.
- **Pipelines as code**: Cloud Build triggers themselves are defined in `pipelines/cloudbuild/triggers.tf`, so the CI/CD wiring is reviewable and versioned, not clicked together in a console.
- **Branch-per-environment delivery**: each environment tracks its own long-lived branch — `develop` -> dev, `staging` -> staging, `main` -> prod. Pushing to a branch applies that environment's infra and deploys the app; PRs against a branch get a plan-only dry run. Prod additionally requires manual approval (`approval_config`) before the apply/deploy actually runs. Cloud Run deploys use a canary + smoke test + traffic promotion pattern.

## Module Map

| Module | Responsibility |
|---|---|
| `modules/shared-vpc-host` | The single VPC, one subnet-per-environment w/ secondary ranges, Cloud Router + NAT, flow logs, baseline firewall, Shared VPC host/service-project attachment, the one-time Cloud SQL private-services peering, and per-environment `compute.networkUser` grants |
| `modules/iam` | Workload + CI/CD service accounts, scoped project IAM bindings, Workload Identity binding |
| `modules/artifact-registry` | Docker repository with tag immutability + cleanup policies |
| `modules/secret-manager` | Secret containers, optional bootstrap versions, per-secret accessor bindings |
| `modules/cloudsql` | Private-IP PostgreSQL, automated backups, PITR, HA option for prod |
| `modules/storage` | Application buckets with versioning + lifecycle rules |
| `modules/monitoring` | Notification channels, log-based error metric + alert policy, billing budget |
| `modules/compute/gke` | Private VPC-native GKE cluster, Workload Identity, autoscaling node pools |
| `modules/compute/cloud-run` | Cloud Run v2 service, Serverless VPC Access connector, Secret Manager env injection, Cloud SQL socket |
| `modules/compute/compute-engine` | Instance template (COS + container), regional MIG, autoscaler, HTTP load balancer |

## Request Flow (example: Cloud Run)

```
Internet -> Cloud Run (managed HTTPS) -> Serverless VPC Access connector
   -> private subnet -> Cloud SQL (private IP) / Secret Manager (via API)
```

## Environment Promotion Flow (branch-per-environment)

```
Branch      Environment   Trigger                          Approval
----------  ------------  -------------------------------  ---------------
develop     dev           push -> plan + apply + deploy     none (auto)
staging     staging       push -> plan + apply + deploy     none (auto)
main        prod          push -> plan; apply/deploy        manual approval
```

```
PR -> develop    -> cloudbuild-infra.yaml (_ACTION=plan, _ENV=dev)        [reviewers see the diff]
push -> develop  -> cloudbuild-infra.yaml (_ACTION=apply, _ENV=dev)
                 -> cloudbuild-app-*.yaml (_ENV=dev)                       [auto]

PR -> staging    -> cloudbuild-infra.yaml (_ACTION=plan, _ENV=staging)
push -> staging  -> cloudbuild-infra.yaml (_ACTION=apply, _ENV=staging)
                 -> cloudbuild-app-*.yaml (_ENV=staging)                   [auto]

PR -> main       -> cloudbuild-infra.yaml (_ACTION=plan, _ENV=prod)
push -> main     -> [manual approval required] -> cloudbuild-infra.yaml (_ACTION=apply, _ENV=prod)
                 -> [manual approval required] -> cloudbuild-app-*.yaml (_ENV=prod)  [canary -> smoke test -> promote]
```

Typical team workflow: feature branches merge into `develop` (auto-deploys to dev) -> `develop` is merged/promoted into `staging` (auto-deploys to staging) -> `staging` is merged/promoted into `main` (deploys to prod after approval). Enforce this order with GitHub branch protection rules (e.g. require `staging` to only accept merges from `develop`, and `main` only from `staging`) if you want to prevent skipping an environment.

## Shared VPC Topology

```
network-hub project (Shared VPC HOST — no app workloads, applied once)
 └── shared-vpc  (single VPC)
       ├── dev-primary      10.10.0.0/20   (region us-central1) ─┐
       ├── staging-primary  10.11.0.0/20   (region us-central1)  ├─ one Cloud Router + Cloud NAT per region
       └── prod-primary     10.12.0.0/20   (region us-central1) ─┘

my-gcp-project-dev      (service project) ── uses dev-primary only
my-gcp-project-staging  (service project) ── uses staging-primary only
my-gcp-project-prod     (service project) ── uses prod-primary only
```

- `environments/network-hub` creates the VPC, all three subnets, NAT, firewall,
  the Shared VPC host/service-project attachment, the single Cloud SQL
  private-services peering for the whole VPC, and `compute.networkUser`
  grants scoped per-subnet.
- `environments/{dev,staging,prod}` no longer create any networking
  resources; they look up their own subnet via `data "google_compute_subnetwork"`
  against the host project and pass that into `modules/iam`, `modules/cloudsql`,
  and whichever `modules/compute/*` platform is selected.
- Firewall rules are evaluated per-subnet (`allow-internal` for `dev` only
  matches `10.10.0.0/20`), so being on the same VPC does not by itself allow
  dev traffic to reach staging or prod.
- Apply order matters: `network-hub` must exist before the first `apply` in
  any of `dev`/`staging`/`prod` (their `data` sources will fail to find the
  subnet otherwise). After that, day-to-day changes to dev/staging/prod
  never need to touch `network-hub` again.

## Extending

- **Add a new environment**: add its CIDR to `environment_subnets` and its
  project to `service_projects` in `environments/network-hub/terraform.tfvars`
  and re-apply `network-hub` first; then copy `environments/dev` to
  `environments/<name>`, edit `terraform.tfvars` (including `host_project_id`),
  point `backend.tf` at a new state bucket, add matching triggers in `triggers.tf`.
- **Switch compute platform**: change `compute_platform` in the environment's `terraform.tfvars` and re-run `terraform plan`. Old compute resources are destroyed and the new platform's resources are created — treat this as a real cutover (test in dev/staging first).
- **Add a secret**: add an entry to the `secrets` map in `environments/<env>/main.tf` (module "secrets" block) and grant `accessor_service_account_emails` as needed.
