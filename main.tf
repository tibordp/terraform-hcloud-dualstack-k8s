variable "name" {
  description = "Name of the cluster"
  type        = string
}

variable "hcloud_ssh_key" {
  description = "SSH key name or ID"
  type        = string
}

variable "master_server_type" {
  description = "Server SKU"
  type        = string
  default     = "cx31"
}

variable "worker_server_type" {
  description = "Server SKU"
  type        = string
  default     = "cx31"
}

variable "hcloud_token" {
  description = "Hetzner token for CCM and storage provisioner"
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
}

variable "image" {
  description = "Image for the nodes"
  type        = string
  default     = "ubuntu-20.04"
}

variable "location" {
  description = "Server location"
  type        = string
  default     = "hel1"
}

variable "ssh_private_key_path" {
  description = "SSH public key file path"
  type        = string
  default     = "~/.ssh/id_rsa"
}

module "master" {
  source = "./modules/k8s-master"

  name           = "${var.name}-master"
  hcloud_ssh_key = var.hcloud_ssh_key
  hcloud_token   = var.hcloud_token
  server_type    = var.master_server_type
  image          = var.image
  location       = var.location

  ssh_private_key_path = var.ssh_private_key_path
}

module "worker" {
  count  = var.worker_count
  source = "./modules/k8s-worker"

  name              = "${var.name}-worker-${count.index}"
  hcloud_ssh_key    = var.hcloud_ssh_key
  master_ip_address = module.master.ipv4_address
  server_type       = var.worker_server_type
  image             = var.image
  location          = var.location

  ssh_private_key_path = var.ssh_private_key_path
}

output "apiserver_ipv4_address" {
  description = "IPv4 address of the API server"
  value       = module.master.ipv4_address
}

output "apiserver_ipv6_address" {
  description = "IPv6 address of the API server"
  value       = module.master.ipv6_address
}

output "kubeconfig" {
  description = "kubeconfig for the cluster"
  value       = module.master.kubeconfig
}

