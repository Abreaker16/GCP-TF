variable "host_project_id" {
  description = "GCP project ID that will act as the Shared VPC host project"
  type        = string
}

variable "region" {
  description = "Primary GCP region (used for Cloud Router/NAT)"
  type        = string
}

variable "network_name" {
  description = "Name of the single shared VPC network"
  type        = string
  default     = "shared-vpc"
}

# One subnet per environment, all inside the same VPC. CIDRs must not overlap
# with each other (or with any other shared VPC subnet you add later).
variable "environment_subnets" {
  description = "Map of environment name => subnet config for that environment's slice of the shared VPC"
  type = map(object({
    ip_cidr_range             = string
    region                    = string
    secondary_ip_range_pods   = string
    secondary_ip_range_svcs   = string
    private_ip_google_access  = optional(bool, true)
  }))
}

variable "enable_cloud_nat" {
  description = "Whether to provision Cloud Router + Cloud NAT for private egress (shared by all environments)"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs on every environment's subnet"
  type        = bool
  default     = true
}

variable "authorized_ip_ranges" {
  description = "CIDR ranges allowed for administrative/IAP SSH access across all environments"
  type        = list(string)
  default     = []
}

# service_projects controls Shared VPC attachment AND the automatic
# compute.networkUser grants. Service account emails are derived from the
# same naming convention modules/iam uses (<env>-<app_name>-runtime /
# -cicd@<project_id>.iam.gserviceaccount.com), so this module does not need
# to depend on the per-environment Terraform state.
variable "service_projects" {
  description = "Map of environment name => service project attached to the shared VPC"
  type = map(object({
    project_id = string
    app_name   = string
  }))
}

variable "labels" {
  description = "Common labels applied to networking resources"
  type        = map(string)
  default     = {}
}
