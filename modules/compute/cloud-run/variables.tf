variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_name" {
  type = string
}

variable "image" {
  description = "Container image to deploy (e.g. REGION-docker.pkg.dev/PROJECT/REPO/app:tag). A placeholder image is fine on first apply; CI/CD updates it afterward."
  type        = string
}

variable "service_account_email" {
  type = string
}

variable "vpc_connector_subnet_id" {
  description = "Subnet ID used for the Serverless VPC Access connector (for private DB access)"
  type        = string
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "secret_env_vars" {
  description = "Map of ENV_VAR_NAME => secret_id to mount from Secret Manager (latest version)"
  type        = map(string)
  default     = {}
}

variable "allow_unauthenticated" {
  type    = bool
  default = false
}

variable "cloudsql_connection_name" {
  description = "Cloud SQL instance connection name for the Cloud SQL proxy sidecar (optional)"
  type        = string
  default     = null
}
