output "network_name" {
  value = data.google_compute_network.shared.name
}

output "subnet_name" {
  value = data.google_compute_subnetwork.primary.name
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "cloudsql_connection_name" {
  value = module.cloudsql.instance_connection_name
}

output "workload_service_account_email" {
  value = module.iam.workload_service_account_email
}

output "cicd_service_account_email" {
  value = module.iam.cicd_service_account_email
}

output "app_endpoint" {
  description = "Public endpoint of the deployed application, whichever compute platform is active"
  value = coalesce(
    try(module.cloud_run[0].service_url, null),
    try(module.compute_engine[0].load_balancer_ip, null),
    try(module.gke[0].get_credentials_command, null)
  )
}
