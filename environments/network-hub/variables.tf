variable "host_project_id" {
  description = "GCP project ID that acts as the Shared VPC host (dedicated networking project, owns no app resources)"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "network_name" {
  type    = string
  default = "shared-vpc"
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "authorized_ip_ranges" {
  description = "CIDR ranges allowed admin/SSH access via IAP, across all environments"
  type        = list(string)
  default     = []
}

# One non-overlapping CIDR block per environment. Keep these far enough
# apart to grow into (e.g. /20 gives ~4k host IPs; pods/svcs ranges are
# sized for GKE but harmless if you run Cloud Run / Compute Engine instead).
variable "environment_subnets" {
  type = map(object({
    ip_cidr_range             = string
    region                    = string
    secondary_ip_range_pods   = string
    secondary_ip_range_svcs   = string
    private_ip_google_access  = optional(bool, true)
  }))

  default = {
    dev = {
      ip_cidr_range            = "10.10.0.0/20"
      region                   = "us-central1"
      secondary_ip_range_pods  = "10.20.0.0/14"
      secondary_ip_range_svcs  = "10.30.0.0/20"
    }
    staging = {
      ip_cidr_range            = "10.11.0.0/20"
      region                   = "us-central1"
      secondary_ip_range_pods  = "10.24.0.0/14"
      secondary_ip_range_svcs  = "10.30.16.0/20"
    }
    prod = {
      ip_cidr_range            = "10.12.0.0/20"
      region                   = "us-central1"
      secondary_ip_range_pods  = "10.28.0.0/14"
      secondary_ip_range_svcs  = "10.30.32.0/20"
    }
  }
}

# The service (app) project for each environment — same project_id values
# you put in environments/<env>/terraform.tfvars, plus the app_name so this
# root can derive the workload/CI-CD service account emails for IAM grants.
variable "service_projects" {
  type = map(object({
    project_id = string
    app_name   = string
  }))

  default = {
    dev = {
      project_id = "my-gcp-project-dev"
      app_name   = "myapp"
    }
    staging = {
      project_id = "my-gcp-project-staging"
      app_name   = "myapp"
    }
    prod = {
      project_id = "my-gcp-project-prod"
      app_name   = "myapp"
    }
  }
}
