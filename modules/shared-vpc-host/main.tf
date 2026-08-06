# ---------------------------------------------------------------------------
# Shared VPC Host Module
#
# Provisions ONE VPC, shared by dev/staging/prod, with one subnet per
# environment. Enables the project as a Shared VPC host and attaches each
# environment's project as a service project. Also creates the single
# service-networking peering used by every environment's Cloud SQL instance
# (private services access is a per-*network* connection, not per-project,
# so it must exist exactly once here rather than in each environment).
# ---------------------------------------------------------------------------

resource "google_compute_network" "shared" {
  project                 = var.host_project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  mtu                     = 1460
}

resource "google_compute_subnetwork" "env" {
  for_each = var.environment_subnets

  project                  = var.host_project_id
  name                     = "${each.key}-primary"
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.shared.id
  private_ip_google_access = each.value.private_ip_google_access

  secondary_ip_range {
    range_name    = "${each.key}-primary-pods"
    ip_cidr_range = each.value.secondary_ip_range_pods
  }

  secondary_ip_range {
    range_name    = "${each.key}-primary-svcs"
    ip_cidr_range = each.value.secondary_ip_range_svcs
  }

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_10_MIN"
      flow_sampling        = 0.5
      metadata              = "INCLUDE_ALL_METADATA"
    }
  }
}

# ---------------------------------------------------------------------------
# Cloud Router + Cloud NAT (one per region present across environments)
# ---------------------------------------------------------------------------
locals {
  nat_regions = toset([for k, v in var.environment_subnets : v.region])
}

resource "google_compute_router" "router" {
  for_each = var.enable_cloud_nat ? local.nat_regions : []

  project = var.host_project_id
  name    = "shared-router-${each.value}"
  region  = each.value
  network = google_compute_network.shared.id
}

resource "google_compute_router_nat" "nat" {
  for_each = var.enable_cloud_nat ? local.nat_regions : []

  project                             = var.host_project_id
  name                                = "shared-nat-${each.value}"
  router                              = google_compute_router.router[each.value].name
  region                              = each.value
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---------------------------------------------------------------------------
# Baseline firewall rules — apply once, cover every environment's subnet.
# Environment isolation between dev/staging/prod at L3 is intentional and
# preserved: "allow_internal" only permits traffic *within each subnet's own
# CIDR*, not across environments. Add explicit rules if you ever need
# cross-environment traffic (generally you should not for prod).
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "deny_all_ingress" {
  project   = var.host_project_id
  name      = "shared-deny-all-ingress"
  network   = google_compute_network.shared.name
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  for_each = var.environment_subnets

  project   = var.host_project_id
  name      = "shared-allow-internal-${each.key}"
  network   = google_compute_network.shared.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  # Scoped to each environment's own subnet range -> keeps dev/staging/prod
  # network-isolated from each other even though they share one VPC.
  source_ranges = [each.value.ip_cidr_range]
  target_tags   = ["env-${each.key}"]
}

resource "google_compute_firewall" "allow_health_checks" {
  project   = var.host_project_id
  name      = "shared-allow-health-checks"
  network   = google_compute_network.shared.name
  direction = "INGRESS"
  priority  = 900

  allow {
    protocol = "tcp"
  }

  # Google Cloud health check ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["allow-health-checks"]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  count = length(var.authorized_ip_ranges) > 0 ? 1 : 0

  project   = var.host_project_id
  name      = "shared-allow-iap-ssh"
  network   = google_compute_network.shared.name
  direction = "INGRESS"
  priority  = 950

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  # 35.235.240.0/20 is Google's Identity-Aware Proxy TCP forwarding range
  source_ranges = concat(["35.235.240.0/20"], var.authorized_ip_ranges)
  target_tags   = ["iap-access"]
}

# ---------------------------------------------------------------------------
# Cloud SQL private services access — ONE peering for the whole shared VPC.
# Every environment's Cloud SQL instance (in its own service project) points
# private_network at this same host VPC, so this only needs to exist once.
# ---------------------------------------------------------------------------
resource "google_compute_global_address" "private_service_range" {
  project       = var.host_project_id
  name          = "shared-sql-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.shared.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.shared.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}

# ---------------------------------------------------------------------------
# Shared VPC: enable this project as host, attach each environment's project
# as a service project.
# ---------------------------------------------------------------------------
resource "google_compute_shared_vpc_host_project" "host" {
  project = var.host_project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  for_each = var.service_projects

  host_project    = var.host_project_id
  service_project = each.value.project_id

  depends_on = [google_compute_shared_vpc_host_project.host]
}

# ---------------------------------------------------------------------------
# compute.networkUser grants, scoped to each environment's own subnet only
# (not the whole host project) — a service project only gets to use the
# slice of the shared VPC that belongs to its environment.
#
# Granted to:
#  - that environment's workload + CI/CD service accounts (created by
#    modules/iam in the environment's own root; the email is deterministic
#    so there's no cross-root dependency/cycle)
#  - the environment's GKE and Serverless VPC Access Google-managed service
#    agents, needed whenever compute_platform = gke / cloud_run
# ---------------------------------------------------------------------------
data "google_project" "service" {
  for_each   = var.service_projects
  project_id = each.value.project_id
}

locals {
  network_user_members = merge([
    for env, sp in var.service_projects : {
      "${env}-workload" = {
        env    = env
        member = "serviceAccount:${env}-${sp.app_name}-runtime@${sp.project_id}.iam.gserviceaccount.com"
      }
      "${env}-cicd" = {
        env    = env
        member = "serviceAccount:${env}-${sp.app_name}-cicd@${sp.project_id}.iam.gserviceaccount.com"
      }
      "${env}-gke-agent" = {
        env    = env
        member = "serviceAccount:service-${data.google_project.service[env].number}@container-engine-robot.iam.gserviceaccount.com"
      }
      "${env}-vpcaccess-agent" = {
        env    = env
        member = "serviceAccount:service-${data.google_project.service[env].number}@gcp-sa-vpcaccess.iam.gserviceaccount.com"
      }
    }
  ]...)
}

resource "google_compute_subnetwork_iam_member" "network_user" {
  for_each = local.network_user_members

  project    = var.host_project_id
  region     = var.environment_subnets[each.value.env].region
  subnetwork = google_compute_subnetwork.env[each.value.env].name
  role       = "roles/compute.networkUser"
  member     = each.value.member
}
