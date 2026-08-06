output "instance_connection_name" {
  description = "Connection name used by the Cloud SQL Auth Proxy / connectors (project:region:instance)"
  value       = google_sql_database_instance.instance.connection_name
}

output "instance_private_ip" {
  value = google_sql_database_instance.instance.private_ip_address
}

output "database_name" {
  value = google_sql_database.database.name
}

output "database_user" {
  value = google_sql_user.app_user.name
}

output "database_password" {
  value     = random_password.db_password.result
  sensitive = true
}
