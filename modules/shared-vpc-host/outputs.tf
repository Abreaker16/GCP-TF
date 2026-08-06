output "network_id" {
  description = "Self-link/ID of the shared VPC"
  value       = google_compute_network.shared.id
}

output "network_name" {
  description = "Name of the shared VPC"
  value       = google_compute_network.shared.name
}

output "network_self_link" {
  description = "Self-link of the shared VPC"
  value       = google_compute_network.shared.self_link
}

output "subnet_ids" {
  description = "Map of environment name => subnet ID"
  value       = { for k, v in google_compute_subnetwork.env : k => v.id }
}

output "subnet_self_links" {
  description = "Map of environment name => subnet self_link"
  value       = { for k, v in google_compute_subnetwork.env : k => v.self_link }
}

output "subnet_names" {
  description = "Map of environment name => subnet name"
  value       = { for k, v in google_compute_subnetwork.env : k => v.name }
}

output "subnet_secondary_ranges" {
  description = "Map of environment name => its pods/services secondary range names"
  value = {
    for k, v in google_compute_subnetwork.env : k => {
      pods_range_name = "${k}-primary-pods"
      svcs_range_name = "${k}-primary-svcs"
    }
  }
}

output "private_vpc_connection" {
  description = "The service networking connection, so environments can (optionally) depend_on it"
  value       = google_service_networking_connection.private_vpc_connection
}
