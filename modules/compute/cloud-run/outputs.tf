output "service_name" {
  value = google_cloud_run_v2_service.service.name
}

output "service_url" {
  value = google_cloud_run_v2_service.service.uri
}

output "vpc_connector_id" {
  value = google_vpc_access_connector.connector.id
}
