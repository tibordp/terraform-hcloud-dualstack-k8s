output "apiserver_ipv4_address" {
  description = "IPv4 address of the API server"
  value       = var.control_plane.high_availability ? hcloud_load_balancer.control_plane[0].ipv4 : module.master[0].ipv4_address
}

output "apiserver_ipv6_address" {
  description = "IPv6 address of the API server"
  value       = var.control_plane.high_availability ? hcloud_load_balancer.control_plane[0].ipv6 : module.master[0].ipv6_address
}

output "client_certificate_data" {
  description = "kubeconfig for the cluster"
  value       = base64decode(module.client_certificate_data.stdout)
}

output "certificate_authority_data" {
  description = "kubeconfig for the cluster"
  value       = base64decode(module.certificate_authority_data.stdout)
}

output "client_key_data" {
  description = "kubeconfig for the cluster"
  value       = base64decode(module.client_key_data.stdout)
}

output "kubeconfig" {
  description = "kubeconfig for the cluster"
  value       = module.kubeconfig.stdout
}