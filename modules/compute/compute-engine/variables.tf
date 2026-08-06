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

variable "subnet_id" {
  type = string
}

variable "service_account_email" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "source_image" {
  description = "Boot image, e.g. cos-cloud/cos-stable, debian-cloud/debian-12, or a custom image"
  type        = string
  default     = "projects/cos-cloud/global/images/family/cos-stable"
}

variable "container_image" {
  description = "Container image to run via Container-Optimized OS (COS) if using the cos-stable image"
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "disk_size_gb" {
  type    = number
  default = 30
}

variable "min_replicas" {
  type    = number
  default = 2
}

variable "max_replicas" {
  type    = number
  default = 10
}

variable "target_cpu_utilization" {
  type    = number
  default = 0.6
}

variable "named_ports" {
  type = list(object({ name = string, port = number }))
  default = [{ name = "http", port = 8080 }]
}
