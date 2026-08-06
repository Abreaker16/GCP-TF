# ---------------------------------------------------------------------------
# Environment root: network-hub
#
# Deploys the Shared VPC HOST project: one VPC, one subnet per environment,
# Cloud NAT, baseline firewall, and Shared VPC service-project attachment
# for dev/staging/prod. Apply this BEFORE the first apply of any of
# environments/{dev,staging,prod} — they read this network via data sources.
#
# This root is intentionally NOT wired to one of the dev/develop/staging/main
# app branches. It changes rarely (new environment, new CIDR, new region) and
# is applied from an admin/platform context, e.g. its own `network` branch or
# manually. See pipelines/cloudbuild/cloudbuild-infra.yaml (_ENV=network-hub).
# ---------------------------------------------------------------------------

provider "google" {
  project = var.host_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.host_project_id
  region  = var.region
}

module "shared_vpc" {
  source = "../../modules/shared-vpc-host"

  host_project_id = var.host_project_id
  region           = var.region
  network_name     = var.network_name

  environment_subnets = var.environment_subnets

  enable_cloud_nat     = true
  enable_flow_logs     = var.enable_flow_logs
  authorized_ip_ranges = var.authorized_ip_ranges

  service_projects = var.service_projects

  labels = {
    managed_by = "terraform"
    purpose    = "shared-vpc-host"
  }
}
