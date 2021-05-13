variable "name" {
  description = "Name of the master"
  type        = string
}

variable "ssh_key" {
  description = "SSH key name"
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