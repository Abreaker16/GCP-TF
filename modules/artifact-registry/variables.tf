variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region for the Artifact Registry repository"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "app_name" {
  type        = string
  description = "Application name used in the repository ID"
}

variable "format" {
  type        = string
  description = "Repository format: DOCKER, MAVEN, NPM, PYTHON, etc."
  default     = "DOCKER"
}

variable "immutable_tags" {
  type        = bool
  description = "Prevent overwriting image tags once pushed (recommended for prod)"
  default     = true
}

variable "cleanup_policy_keep_count" {
  type        = number
  description = "Number of most recent versions to retain per image"
  default     = 20
}
