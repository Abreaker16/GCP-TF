output "notification_channel_ids" {
  value = { for k, v in google_monitoring_notification_channel.channel : k => v.id }
}

output "alert_policy_id" {
  value = google_monitoring_alert_policy.error_rate.id
}

output "log_sink_writer_identity" {
  value = var.log_sink_destination != null ? google_logging_project_sink.platform_sink[0].writer_identity : null
}
