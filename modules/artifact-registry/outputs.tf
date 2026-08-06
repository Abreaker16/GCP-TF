output "repository_id" {
  value       = google_artifact_registry_repository.repo.repository_id
  description = "Repository ID"
}

output "repository_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
  description = "Full repository URL used for docker push/pull"
}
