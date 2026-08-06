variable "project_id" {
  type        = string
  description = "GCP project ID for this environment"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "app_name" {
  type    = string
  default = "myapp"
}

variable "compute_platform" {
  description = "Which compute platform to deploy: gke, cloud_run, or compute_engine"
  type        = string
  default     = "cloud_run"

  validation {
    condition     = contains(["gke", "cloud_run", "compute_engine"], var.compute_platform)
    error_message = "compute_platform must be one of: gke, cloud_run, compute_engine."
  }
}

variable "container_image" {
  description = "Placeholder/initial container image. CI/CD pipeline updates this on every deploy."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "authorized_ip_ranges" {
  description = "CIDR ranges allowed admin/SSH access via IAP"
  type        = list(string)
  default     = []
}

variable "billing_account_id" {
  type    = string
  default = null
}

variable "budget_amount" {
  type    = number
  default = 500
}

variable "notification_email" {
  description = "Email address for monitoring alert notifications"
  type        = string
}

variable "host_project_id" {
  description = "GCP project ID of the Shared VPC host (deployed once via environments/network-hub)"
  type        = string
}

variable "shared_vpc_network_name" {
  description = "Name of the shared VPC network in the host project"
  type        = string
  default     = "shared-vpc"
}
