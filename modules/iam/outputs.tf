output "workload_service_account_email" {
  description = "Email of the application runtime service account"
  value       = google_service_account.workload.email
}

output "workload_service_account_name" {
  description = "Fully qualified resource name of the workload service account"
  value       = google_service_account.workload.name
}

output "cicd_service_account_email" {
  description = "Email of the CI/CD (Cloud Build) service account"
  value       = google_service_account.cicd.email
}

output "cicd_service_account_name" {
  description = "Fully qualified resource name of the CI/CD service account"
  value       = google_service_account.cicd.name
}
