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

variable "network_id" {
  type        = string
  description = "VPC self-link/ID"
}

variable "subnet_id" {
  type        = string
  description = "Subnet self-link/ID for the cluster nodes"
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "enable_private_nodes" {
  type    = bool
  default = true
}

variable "master_ipv4_cidr_block" {
  type    = string
  default = "172.16.0.0/28"
}

variable "authorized_master_cidrs" {
  description = "CIDR ranges allowed to reach the GKE control plane"
  type        = list(object({ cidr_block = string, display_name = string }))
  default     = []
}

variable "node_pools" {
  description = "Map of node pool name => config"
  type = map(object({
    machine_type   = string
    min_count      = number
    max_count      = number
    disk_size_gb   = optional(number, 100)
    disk_type      = optional(string, "pd-standard")
    spot           = optional(bool, false)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {
    default = {
      machine_type = "e2-standard-4"
      min_count    = 1
      max_count    = 5
    }
  }
}

variable "workload_service_account_email" {
  type        = string
  description = "Email of the SA nodes run as (least privilege; app auth via Workload Identity)"
}

variable "maintenance_start_time" {
  type    = string
  default = "2026-01-01T03:00:00Z"
}
