# ---------------------------------------------------------------------------
# Cloud SQL Module
# Private-IP-only PostgreSQL instance with automated backups, PITR,
# and optional regional HA for production workloads.
# ---------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 2
}

resource "google_sql_database_instance" "instance" {
  project             = var.project_id
  name                = "${var.environment}-${var.app_name}-${random_id.suffix.hex}"
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_autoresize   = var.disk_autoresize
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network_id
      require_ssl     = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = var.point_in_time_recovery
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "500"
    }
  }

  lifecycle {
    prevent_destroy = false # set true manually for prod after first apply if desired
  }

  depends_on = var.private_vpc_connection
}

resource "google_sql_database" "database" {
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  name     = var.database_name
}

resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "google_sql_user" "app_user" {
  project  = var.project_id
  instance = google_sql_database_instance.instance.name
  name     = var.database_user
  password = random_password.db_password.result
}
