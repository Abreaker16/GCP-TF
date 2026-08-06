# ---------------------------------------------------------------------------
# Cloud Build Triggers (managed as code) — branch-per-environment model
#
# Branch -> Environment mapping:
#   develop  -> dev       (auto plan + auto apply + auto app deploy)
#   staging  -> staging   (auto plan + auto apply + auto app deploy)
#   main     -> prod      (auto plan, MANUAL APPROVAL required before apply/deploy)
#
# Pull requests targeting any of these branches trigger a plan-only run so
# reviewers can see the infra diff before merge.
#
# Apply this file from a bootstrap/CI-management project or account that has
# repo admin access. Requires the GitHub App / Cloud Build repository
# connection to already exist (one-time console/gcloud step) — see
# scripts/bootstrap.sh.
# ---------------------------------------------------------------------------

variable "repo_owner" {
  type = string
}

variable "repo_name" {
  type = string
}

variable "github_connection_name" {
  description = "Name of the Cloud Build 2nd-gen GitHub connection"
  type        = string
  default     = "github-connection"
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "app_name" {
  type    = string
  default = "myapp"
}

# Per-environment branch + deploy pipeline configuration.
# `app_pipeline` must match the compute_platform set in that environment's
# terraform.tfvars (cloud-run | gke | compute).
variable "environments" {
  description = "Map of environment name => branch/pipeline configuration"
  type = map(object({
    branch              = string   # exact branch name this environment deploys from
    app_pipeline        = string   # cloudbuild-app-<app_pipeline>.yaml
    require_approval    = bool     # manual approval gate before apply/deploy
  }))
  default = {
    dev = {
      branch           = "develop"
      app_pipeline     = "cloudrun"
      require_approval = false
    }
    staging = {
      branch           = "staging"
      app_pipeline     = "cloudrun"
      require_approval = false
    }
    prod = {
      branch           = "main"
      app_pipeline     = "cloudrun"
      require_approval = true
    }
  }
}

variable "network_hub_branch" {
  description = "Branch that environments/network-hub (the Shared VPC host) plans from. Kept plan-only in CI; apply it manually/from an admin context since it's rare and high blast-radius (see scripts/bootstrap.sh)."
  type        = string
  default     = "network"
}

data "google_cloudbuildv2_repository" "repo" {
  project           = var.project_id
  location          = var.region
  name              = var.repo_name
  parent_connection = var.github_connection_name
}

# ---------------------------------------------------------------------------
# Shared VPC host: plan-only on PRs/pushes to the `network` branch. This
# deliberately has no auto-apply trigger — apply it by hand
# (terraform apply in environments/network-hub) after review, since it must
# run once before dev/staging/prod and changes to it affect all three.
# ---------------------------------------------------------------------------
resource "google_cloudbuild_trigger" "network_hub_plan" {
  project  = var.project_id
  location = var.region
  name     = "infra-plan-network-hub"

  repository_event_config {
    repository = data.google_cloudbuildv2_repository.repo.id
    push {
      branch = "^${var.network_hub_branch}$"
    }
  }

  included_files = ["environments/network-hub/**", "modules/shared-vpc-host/**"]
  filename       = "pipelines/cloudbuild/cloudbuild-infra.yaml"

  substitutions = {
    _ENV    = "network-hub"
    _ACTION = "plan"
  }
}

# ---------------------------------------------------------------------------
# Infra: plan on every PR targeting an environment branch
# ---------------------------------------------------------------------------
resource "google_cloudbuild_trigger" "infra_plan_pr" {
  for_each = var.environments

  project  = var.project_id
  location = var.region
  name     = "infra-plan-${each.key}-pr"

  repository_event_config {
    repository = data.google_cloudbuildv2_repository.repo.id
    pull_request {
      branch = "^${each.value.branch}$"
    }
  }

  included_files = ["environments/${each.key}/**", "modules/**"]
  filename       = "pipelines/cloudbuild/cloudbuild-infra.yaml"

  substitutions = {
    _ENV    = each.key
    _ACTION = "plan"
  }
}

# ---------------------------------------------------------------------------
# Infra: apply on push to the environment's branch
# Prod's push trigger still fires on push to `main`, but requires manual
# approval in the Cloud Build console/API before the build actually runs.
# ---------------------------------------------------------------------------
resource "google_cloudbuild_trigger" "infra_apply" {
  for_each = var.environments

  project  = var.project_id
  location = var.region
  name     = "infra-apply-${each.key}"

  repository_event_config {
    repository = data.google_cloudbuildv2_repository.repo.id
    push {
      branch = "^${each.value.branch}$"
    }
  }

  included_files = ["environments/${each.key}/**", "modules/**"]
  filename       = "pipelines/cloudbuild/cloudbuild-infra.yaml"

  substitutions = {
    _ENV    = each.key
    _ACTION = "apply"
  }

  dynamic "approval_config" {
    for_each = each.value.require_approval ? [1] : []
    content {
      approval_required = true
    }
  }
}

# ---------------------------------------------------------------------------
# App: build, scan, push, and deploy on push to the environment's branch.
# Runs after infra_apply for the same branch (Cloud Build has no native
# "depends on other trigger" ordering; in practice the infra trigger's
# apply completes in seconds-to-minutes and the app pipeline is idempotent
# against existing infra, so parallel execution is safe. If you need a
# strict sequence, chain them with a single combined build file instead.)
# ---------------------------------------------------------------------------
resource "google_cloudbuild_trigger" "app_deploy" {
  for_each = var.environments

  project  = var.project_id
  location = var.region
  name     = "app-deploy-${each.key}"

  repository_event_config {
    repository = data.google_cloudbuildv2_repository.repo.id
    push {
      branch = "^${each.value.branch}$"
    }
  }

  included_files = ["src/**", "Dockerfile"]
  filename       = "pipelines/cloudbuild/cloudbuild-app-${each.value.app_pipeline}.yaml"

  substitutions = {
    _ENV      = each.key
    _REGION   = var.region
    _APP_NAME = var.app_name
  }

  dynamic "approval_config" {
    for_each = each.value.require_approval ? [1] : []
    content {
      approval_required = true
    }
  }
}
