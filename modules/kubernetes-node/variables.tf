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

variable "image" {
  description = "Image for the nodes"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
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

variable "firewall_ids" {
  description = "List of firewalls attached to this server"
  type        = list(number)
  default     = []
}

variable "labels" {
  description = "Labels attached to the server"
  type        = map(any)
  default     = {}
}
