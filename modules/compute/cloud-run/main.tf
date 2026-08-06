# ---------------------------------------------------------------------------
# Cloud Run Compute Module
# Deploys a fully-managed Cloud Run v2 service with a Serverless VPC Access
# connector for private networking, Secret Manager-mounted env vars, and
# optional Cloud SQL socket connectivity.
# ---------------------------------------------------------------------------

resource "google_vpc_access_connector" "connector" {
  project       = var.project_id
  name          = substr("${var.environment}-${var.app_name}-conn", 0, 25)
  region        = var.region
  subnet {
    name = var.vpc_connector_subnet_id
  }
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}

resource "google_cloud_run_v2_service" "service" {
  project  = var.project_id
  name     = "${var.environment}-${var.app_name}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    dynamic "volumes" {
      for_each = var.cloudsql_connection_name != null ? [1] : []
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [var.cloudsql_connection_name]
        }
      }
    }

    containers {
      image = var.image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = true
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      dynamic "volume_mounts" {
        for_each = var.cloudsql_connection_name != null ? [1] : []
        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      startup_probe {
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold      = 3
        tcp_socket {
          port = var.container_port
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
