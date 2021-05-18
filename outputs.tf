output "masters" {
  description = "Master nodes"
  value       = module.master
}

output "workers" {
  description = "Worker nodes"
  value       = module.worker
}

output "load_balancer" {
  description = "Worker nodes"
  value       = local.use_load_balancer ? hcloud_load_balancer.control_plane[0] : null
}

output "apiserver_url" {
  description = "URL for the API server"
  value       = "https://${local.control_plane_endpoint}:6443"
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