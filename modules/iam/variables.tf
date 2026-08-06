variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name, used to name service accounts"
  type        = string
}

variable "workload_service_account_roles" {
  description = "Project-level IAM roles granted to the application runtime service account"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
    "roles/secretmanager.secretAccessor",
  ]
}

variable "cicd_service_account_roles" {
  description = "Project-level IAM roles granted to the CI/CD (Cloud Build) service account"
  type        = list(string)
  default = [
    "roles/artifactregistry.writer",
    "roles/container.developer",
    "roles/run.developer",
    "roles/compute.instanceAdmin.v1",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin",
    "roles/cloudsql.client",
  ]
}

variable "enable_workload_identity" {
  description = "Bind the workload service account for GKE Workload Identity"
  type        = bool
  default     = true
}

variable "gke_namespace_ksa" {
  description = "Kubernetes namespace/service-account pair (namespace/ksa-name) for Workload Identity binding"
  type        = string
  default     = "default/app-ksa"
}
