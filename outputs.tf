output "name" {
  description = "name of the cluster"
  value       = var.name
}

output "control_plane_nodes" {
  description = "control plane nodes"
  value       = module.control_plane
}

output "load_balancer" {
  description = "load balancer for the control plane"
  value       = local.use_load_balancer ? hcloud_load_balancer.control_plane[0] : null
}

output "apiserver_url" {
  description = "URL for the API server"
  value       = "https://${local.control_plane_endpoint}:6443"
}

output "client_certificate_data" {
  description = "client certificate"
  value       = local.client_certificate_data
}

output "certificate_authority_data" {
  description = "cluster CA certificate"
  value       = local.certificate_authority_data
}

output "client_key_data" {
  description = "client certificate private key"
  value       = local.client_key_data
  sensitive   = true
}

output "kubeconfig" {
  description = "kubeconfig for the cluster"
  value       = module.kubeconfig.stdout
  sensitive   = true
}

output "join_user_data" {
  description = "cloud-init user data for additional worker nodes"
  value       = data.cloudinit_config.join_config.rendered
  sensitive   = true
}

output "join_command" {
  description = "kubeadm join command for additional worker nodes"
  value       = module.join_config.stdout
  sensitive   = true
}
