output "secret_ids" {
  description = "Map of secret name to its full Secret Manager resource ID"
  value       = { for k, v in google_secret_manager_secret.secret : k => v.id }
}

output "secret_names" {
  description = "Map of secret name to its Secret Manager secret_id (with environment prefix)"
  value       = { for k, v in google_secret_manager_secret.secret : k => v.secret_id }
}
