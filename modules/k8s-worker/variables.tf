variable "name" {
  description = "Name of the instance"
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

variable "master_ip_address" {
  description = "IP address of the master"
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