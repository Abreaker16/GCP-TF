# ---------------------------------------------------------------------------
# Compute Engine Module
# Managed Instance Group running a container via Container-Optimized OS,
# fronted by a regional HTTP(S) Load Balancer, with autoscaling based on
# CPU utilization and rolling-update managed instance refresh.
# ---------------------------------------------------------------------------

resource "google_compute_instance_template" "template" {
  project      = var.project_id
  name_prefix  = "${var.environment}-${var.app_name}-tmpl-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = var.source_image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-ssd"
  }

  network_interface {
    subnetwork = var.subnet_id
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  tags = ["allow-health-checks", "${var.app_name}-${var.environment}"]

  metadata = {
    gce-container-declaration = yamlencode({
      spec = {
        containers = [{
          name  = var.app_name
          image = var.container_image
          ports = [{ containerPort = var.container_port }]
        }]
        restartPolicy = "Always"
      }
    })
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "http" {
  project = var.project_id
  name    = "${var.environment}-${var.app_name}-hc"

  http_health_check {
    port = var.container_port
    request_path = "/healthz"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_region_instance_group_manager" "mig" {
  project            = var.project_id
  name               = "${var.environment}-${var.app_name}-mig"
  region             = var.region
  base_instance_name = "${var.environment}-${var.app_name}"

  version {
    instance_template = google_compute_instance_template.template.id
  }

  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http.id
    initial_delay_sec = 60
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 3
    max_unavailable_fixed = 0
  }
}

resource "google_compute_region_autoscaler" "autoscaler" {
  project = var.project_id
  name    = "${var.environment}-${var.app_name}-as"
  region  = var.region
  target  = google_compute_region_instance_group_manager.mig.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 60

    cpu_utilization {
      target = var.target_cpu_utilization
    }
  }
}

resource "google_compute_backend_service" "backend" {
  project               = var.project_id
  name                  = "${var.environment}-${var.app_name}-backend"
  protocol              = "HTTP"
  port_name             = var.named_ports[0].name
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.http.id]

  backend {
    group = google_compute_region_instance_group_manager.mig.instance_group
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "url_map" {
  project         = var.project_id
  name            = "${var.environment}-${var.app_name}-urlmap"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  project = var.project_id
  name    = "${var.environment}-${var.app_name}-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "${var.environment}-${var.app_name}-lb-ip"
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${var.environment}-${var.app_name}-fr-http"
  target                = google_compute_target_http_proxy.http_proxy.id
  port_range            = "80"
  ip_address            = google_compute_global_address.lb_ip.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
