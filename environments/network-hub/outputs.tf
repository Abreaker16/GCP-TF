output "network_name" {
  value = module.shared_vpc.network_name
}

output "network_self_link" {
  value = module.shared_vpc.network_self_link
}

output "subnet_self_links" {
  value = module.shared_vpc.subnet_self_links
}
