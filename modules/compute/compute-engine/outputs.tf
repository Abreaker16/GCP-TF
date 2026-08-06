output "instance_group_manager" {
  value = google_compute_region_instance_group_manager.mig.self_link
}

output "load_balancer_ip" {
  value       = google_compute_global_address.lb_ip.address
  description = "Public IP of the HTTP(S) load balancer front-end"
}

output "backend_service_id" {
  value = google_compute_backend_service.backend.id
}
