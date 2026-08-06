#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time bootstrap: run manually (or via a bootstrap-only CI job) BEFORE
# the first `terraform init` in any environment. Creates the GCS state
# buckets, enables required APIs, and connects the GitHub repo to Cloud
# Build (2nd-gen). Requires an authenticated gcloud with owner/editor on
# each target project.
#
# Usage: ./scripts/bootstrap.sh <project_id> <environment> <region>
#   environment: dev | staging | prod | network-hub
#
# Run it once for network-hub (the Shared VPC host project) BEFORE running
# it for dev/staging/prod. dev/staging/prod also need
# `gcloud services enable compute.googleapis.com` on the HOST project done
# implicitly here, plus roles/compute.xpnAdmin on the host project for
# whoever applies environments/network-hub.
# ---------------------------------------------------------------------------
set -euo pipefail

PROJECT_ID="${1:?Usage: $0 <project_id> <environment> <region>}"
ENVIRONMENT="${2:?Usage: $0 <project_id> <environment> <region>}"
REGION="${3:-us-central1}"

if [[ "${ENVIRONMENT}" == "network-hub" ]]; then
  echo ">>> Enabling required APIs on Shared VPC host project ${PROJECT_ID} ..."
  gcloud services enable \
    compute.googleapis.com \
    servicenetworking.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    cloudbuild.googleapis.com \
    --project "${PROJECT_ID}"
else
  echo ">>> Enabling required APIs on ${PROJECT_ID} ..."
  gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    run.googleapis.com \
    sqladmin.googleapis.com \
    servicenetworking.googleapis.com \
    secretmanager.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    vpcaccess.googleapis.com \
    billingbudgets.googleapis.com \
    --project "${PROJECT_ID}"
fi

STATE_BUCKET="${PROJECT_ID}-tfstate-${ENVIRONMENT}"
echo ">>> Creating Terraform state bucket gs://${STATE_BUCKET} ..."
gcloud storage buckets create "gs://${STATE_BUCKET}" \
  --project "${PROJECT_ID}" \
  --location "${REGION}" \
  --uniform-bucket-level-access \
  --public-access-prevention || echo "Bucket may already exist, continuing."

gcloud storage buckets update "gs://${STATE_BUCKET}" --versioning

echo ">>> Update environments/${ENVIRONMENT}/backend.tf bucket to: ${STATE_BUCKET}"
if [[ "${ENVIRONMENT}" == "network-hub" ]]; then
  echo ">>> Grant whoever applies environments/network-hub 'roles/compute.xpnAdmin' on"
  echo "    ${PROJECT_ID} (Shared VPC host admin), plus roles/resourcemanager.projectIamAdmin"
  echo "    or roles/owner on each dev/staging/prod service project so it can attach them."
  echo ">>> Next: terraform init && terraform apply in environments/network-hub — do this"
  echo "    BEFORE bootstrapping/applying dev, staging, or prod."
else
  echo ">>> Next: connect this repo to Cloud Build (console: Cloud Build > Repositories > Connect),"
  echo "    then run: terraform init && terraform apply in environments/${ENVIRONMENT}"
fi
