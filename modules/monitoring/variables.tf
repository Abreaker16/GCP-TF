variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_name" {
  type = string
}

variable "notification_channels" {
  description = "Map of channel key => { type, labels } e.g. email, slack, pagerduty"
  type = map(object({
    type   = string
    labels = map(string)
  }))
  default = {}
}

variable "log_sink_destination" {
  description = "Destination for the platform-wide log sink, e.g. a BigQuery dataset or storage bucket resource ID. Leave null to skip."
  type        = string
  default     = null
}

variable "budget_amount" {
  description = "Monthly budget amount (in the billing account's currency) to alert on. Leave null to skip budget alert."
  type        = number
  default     = null
}

variable "billing_account_id" {
  type    = string
  default = null
}

variable "error_rate_threshold" {
  description = "Error count threshold within a 5 minute window that triggers an alert"
  type        = number
  default     = 10
}
