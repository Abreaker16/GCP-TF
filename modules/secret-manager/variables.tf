variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "secrets" {
  description = "Map of secret_name => optional initial value. If value is null, only the secret container is created and versions are managed outside Terraform (recommended for real credentials)."
  type = map(object({
    initial_value = optional(string)
    labels        = optional(map(string), {})
  }))
  default = {}
}

variable "accessor_service_account_emails" {
  description = "Service account emails granted secretAccessor role on every secret in this module"
  type        = list(string)
  default     = []
}

variable "replication" {
  description = "Replication policy: 'automatic' or a list of regions for user-managed replication"
  type        = string
  default     = "automatic"
}
