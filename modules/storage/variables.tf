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

variable "buckets" {
  description = "Map of logical bucket key => config"
  type = map(object({
    location                    = optional(string)
    storage_class                = optional(string, "STANDARD")
    versioning                   = optional(bool, true)
    uniform_bucket_level_access  = optional(bool, true)
    lifecycle_age_days           = optional(number, 90)
    public_access_prevention     = optional(string, "enforced")
  }))
  default = {
    app_assets = {}
    tf_artifacts = {}
  }
}
