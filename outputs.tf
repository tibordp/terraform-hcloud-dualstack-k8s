output "apiserver_ipv4_address" {
  description = "IPv4 address of the API server"
  value       = module.master.ipv4_address
}

output "apiserver_ipv6_address" {
  description = "IPv6 address of the API server"
  value       = module.master.ipv6_address
}

output "client_certificate_data" {
  description = "kubeconfig for the cluster"
  value       = module.client_certificate_data.stdout
}

output "certificate_authority_data" {
  description = "kubeconfig for the cluster"
  value       = module.certificate_authority_data.stdout
}

output "client_key_data" {
  description = "kubeconfig for the cluster"
  value       = module.client_key_data.stdout
}

output "kubeconfig" {
  description = "kubeconfig for the cluster"
  value       = module.kubeconfig.stdout
}