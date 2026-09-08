host_project_id      = "shared-vpc-internal-poc-tf"   # dedicated networking-only project
region               = "asia-south1"
network_name         = "shared-vpc"
enable_flow_logs     = true
authorized_ip_ranges = ["203.0.113.0/24"]           # your office/VPN CIDR for IAP SSH

# Keep in sync with each environments/<env>/terraform.tfvars project_id + app_name.
environment_subnets = {
  dev = {
    ip_cidr_range            = "10.10.0.0/20"
    region                   = "us-central1"
    secondary_ip_range_pods  = "10.20.0.0/14"
    secondary_ip_range_svcs  = "10.30.0.0/20"
  }
  staging = {
    ip_cidr_range            = "10.11.0.0/20"
    region                   = "us-central1"
    secondary_ip_range_pods  = "10.24.0.0/14"
    secondary_ip_range_svcs  = "10.30.16.0/20"
  }
  prod = {
    ip_cidr_range            = "10.12.0.0/20"
    region                   = "us-central1"
    secondary_ip_range_pods  = "10.28.0.0/14"
    secondary_ip_range_svcs  = "10.30.32.0/20"
  }
}

service_projects = {
  dev = {
    project_id = "my-gcp-project-dev"
    app_name   = "myapp"
  }
  staging = {
    project_id = "my-gcp-project-staging"
    app_name   = "myapp"
  }
  prod = {
    project_id = "my-gcp-project-prod"
    app_name   = "myapp"
  }
}
