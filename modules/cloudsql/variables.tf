variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region for the Cloud SQL instance"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "app_name" {
  type        = string
  description = "Application name used for instance/database naming"
}

variable "database_version" {
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  type        = string
  description = "Machine tier, e.g. db-custom-2-7680 or db-f1-micro for dev"
  default     = "db-custom-2-7680"
}

variable "availability_type" {
  type        = string
  description = "ZONAL or REGIONAL (REGIONAL = HA with automatic failover)"
  default     = "ZONAL"
}

variable "vpc_network_id" {
  type        = string
  description = "Self-link/ID of the VPC network for private IP connectivity"
}

variable "private_vpc_connection" {
  description = "Wrap the google_service_networking_connection resource in a list (e.g. [google_service_networking_connection.x]) so this module can depend_on it before instance creation. Pass [] when the peering is managed elsewhere (e.g. the shared VPC host project) and already applied."
  type        = list(any)
  default     = []
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "disk_autoresize" {
  type    = bool
  default = true
}

variable "backup_start_time" {
  type    = string
  default = "03:00"
}

variable "point_in_time_recovery" {
  type        = bool
  description = "Enable PITR via WAL archiving (recommended for prod)"
  default     = true
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "database_name" {
  type    = string
  default = "appdb"
}

variable "database_user" {
  type    = string
  default = "app_user"
}

variable "maintenance_window_day" {
  type    = number
  default = 7 # Sunday
}

variable "maintenance_window_hour" {
  type    = number
  default = 4
}

variable "query_insights_enabled" {
  type    = bool
  default = true
}
