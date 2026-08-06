# ---------------------------------------------------------------------------
# Monitoring Module
# Notification channels, log-based error metric + alert policy, and an
# optional billing budget alert for cost governance.
# ---------------------------------------------------------------------------

resource "google_monitoring_notification_channel" "channel" {
  for_each     = var.notification_channels
  project      = var.project_id
  display_name = "${var.environment}-${each.key}"
  type         = each.value.type
  labels       = each.value.labels
}

resource "google_logging_metric" "app_errors" {
  project = var.project_id
  name    = "${var.environment}-${var.app_name}-error-count"
  filter  = "resource.type=(\"k8s_container\" OR \"cloud_run_revision\" OR \"gce_instance\") AND severity>=ERROR AND labels.app=\"${var.app_name}\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "error_rate" {
  project      = var.project_id
  display_name = "${var.environment}-${var.app_name}-high-error-rate"
  combiner     = "OR"
  notification_channels = [for c in google_monitoring_notification_channel.channel : c.id]

  conditions {
    display_name = "Error count exceeds threshold"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.app_errors.name}\" AND resource.type=\"global\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Error rate for ${var.app_name} in ${var.environment} exceeded ${var.error_rate_threshold} errors / 5 min. Check Cloud Logging and recent deploys."
    mime_type = "text/markdown"
  }
}

resource "google_logging_project_sink" "platform_sink" {
  count                  = var.log_sink_destination != null ? 1 : 0
  project                = var.project_id
  name                   = "${var.environment}-${var.app_name}-sink"
  destination            = var.log_sink_destination
  filter                 = "severity>=WARNING"
  unique_writer_identity = true
}

resource "google_billing_budget" "budget" {
  count           = var.budget_amount != null && var.billing_account_id != null ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "${var.environment}-${var.app_name}-monthly-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    monitoring_notification_channels = [for c in google_monitoring_notification_channel.channel : c.id]
  }
}
