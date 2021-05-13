variable "name" {
  description = "Name of the master"
  type        = string
}

variable "hcloud_ssh_key" {
  description = "SSH key name or ID"
  type        = string
}

variable "server_type" {
  description = "Server SKU"
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner token for CCM and storage provisioner"
  type        = string
}

variable "image" {
  description = "Image for the nodes"
  type        = string
}

variable "location" {
  description = "Server location"
  type        = string
}

variable "ssh_private_key_path" {
  description = "SSH public key file path"
  type        = string
}