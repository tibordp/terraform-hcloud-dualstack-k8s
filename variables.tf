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

variable "master_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
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