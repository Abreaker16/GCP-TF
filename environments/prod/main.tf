# ---------------------------------------------------------------------------
# Environment root: dev
# Composes all platform modules. This same structure is mirrored in
# environments/staging and environments/prod with different tfvars/backend.
# ---------------------------------------------------------------------------

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  common_labels = {
    environment = var.environment
    app         = var.app_name
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Networking — Shared VPC
#
# This environment does NOT create its own VPC. It reads its subnet from the
# shared VPC host project (deployed once via environments/network-hub, which
# must be applied first). All three environments (dev/staging/prod) share
# one VPC but each gets its own non-overlapping subnet/CIDR, so they are
# still network-isolated from each other at L3 — see
# modules/shared-vpc-host's firewall rules.
#
# The Shared VPC service-project attachment and the compute.networkUser IAM
# grants that let this project's service accounts use the subnet are also
# created by environments/network-hub — nothing further is needed here.
# ---------------------------------------------------------------------------
data "google_compute_network" "shared" {
  project = var.host_project_id
  name    = var.shared_vpc_network_name
}

data "google_compute_subnetwork" "primary" {
  project = var.host_project_id
  region  = var.region
  name    = "${var.environment}-primary"
}

locals {
  pods_range_name = "${var.environment}-primary-pods"
  svcs_range_name = "${var.environment}-primary-svcs"
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  environment = var.environment
  app_name    = var.app_name

  enable_workload_identity = var.compute_platform == "gke"
  gke_namespace_ksa         = "default/${var.app_name}-ksa"
}

# ---------------------------------------------------------------------------
# Artifact Registry
# ---------------------------------------------------------------------------
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id     = var.project_id
  region         = var.region
  environment    = var.environment
  app_name       = var.app_name
  immutable_tags = var.environment == "prod"
}

# ---------------------------------------------------------------------------
# Secret Manager
# ---------------------------------------------------------------------------
module "secrets" {
  source = "../../modules/secret-manager"

  project_id  = var.project_id
  environment = var.environment

  secrets = {
    db-password = { initial_value = module.cloudsql.database_password }
    app-config  = { initial_value = null } # populated out-of-band / via CI
  }

  accessor_service_account_emails = [
    module.iam.workload_service_account_email
  ]
}

# ---------------------------------------------------------------------------
# Cloud SQL
# ---------------------------------------------------------------------------
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id              = var.project_id
  region                  = var.region
  environment             = var.environment
  app_name                = var.app_name
  vpc_network_id           = data.google_compute_network.shared.id
  private_vpc_connection   = [] # peering already established once by environments/network-hub
  availability_type        = var.environment == "prod" ? "REGIONAL" : "ZONAL"
  tier                     = var.environment == "prod" ? "db-custom-4-16384" : "db-custom-1-3840"
  deletion_protection      = var.environment == "prod"
  point_in_time_recovery   = var.environment != "dev"
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------
module "storage" {
  source = "../../modules/storage"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  app_name    = var.app_name

  buckets = {
    app_assets   = { lifecycle_age_days = 90 }
    tf_artifacts = { lifecycle_age_days = 30, versioning = true }
  }
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  project_id  = var.project_id
  environment = var.environment
  app_name    = var.app_name

  notification_channels = {
    email = {
      type   = "email"
      labels = { email_address = var.notification_email }
    }
  }

  billing_account_id = var.billing_account_id
  budget_amount       = var.budget_amount
}

# ---------------------------------------------------------------------------
# Compute platform (choose exactly one via var.compute_platform)
# ---------------------------------------------------------------------------
module "gke" {
  count  = var.compute_platform == "gke" ? 1 : 0
  source = "../../modules/compute/gke"

  project_id           = var.project_id
  region               = var.region
  environment          = var.environment
  app_name             = var.app_name
  network_id           = data.google_compute_network.shared.id
  subnet_id            = data.google_compute_subnetwork.primary.id
  pods_range_name      = local.pods_range_name
  services_range_name  = local.svcs_range_name

  workload_service_account_email = module.iam.workload_service_account_email

  node_pools = {
    default = {
      machine_type = var.environment == "prod" ? "e2-standard-4" : "e2-standard-2"
      min_count    = var.environment == "prod" ? 2 : 1
      max_count    = var.environment == "prod" ? 10 : 3
    }
  }
}

module "cloud_run" {
  count  = var.compute_platform == "cloud_run" ? 1 : 0
  source = "../../modules/compute/cloud-run"

  project_id              = var.project_id
  region                  = var.region
  environment             = var.environment
  app_name                = var.app_name
  image                   = var.container_image
  service_account_email    = module.iam.workload_service_account_email
  vpc_connector_subnet_id  = data.google_compute_subnetwork.primary.id
  cloudsql_connection_name = module.cloudsql.instance_connection_name
  min_instances            = var.environment == "prod" ? 1 : 0
  max_instances            = var.environment == "prod" ? 20 : 5
  allow_unauthenticated     = var.environment != "prod"

  secret_env_vars = {
    DB_PASSWORD = module.secrets.secret_names["db-password"]
  }

  env_vars = {
    ENVIRONMENT = var.environment
    DB_NAME     = module.cloudsql.database_name
    DB_USER     = module.cloudsql.database_user
  }
}

module "compute_engine" {
  count  = var.compute_platform == "compute_engine" ? 1 : 0
  source = "../../modules/compute/compute-engine"

  project_id             = var.project_id
  region                 = var.region
  environment            = var.environment
  app_name               = var.app_name
  subnet_id               = data.google_compute_subnetwork.primary.id
  service_account_email   = module.iam.workload_service_account_email
  container_image         = var.container_image
  min_replicas             = var.environment == "prod" ? 2 : 1
  max_replicas             = var.environment == "prod" ? 20 : 5
}
