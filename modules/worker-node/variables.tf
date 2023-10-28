variable "name" {
  description = "Name of the node pool"
  type        = string
}

variable "cluster" {
  description = "kubernetes cluster"
}

variable "hcloud_ssh_key" {
  description = "SSH key name or ID"
  type        = string
}

variable "server_type" {
  description = "Server SKU (default: 'cx31')"
  type        = string
  default     = "cx31"
}

variable "image" {
  description = "Image for the nodes (default: ubuntu-22.04)"
  type        = string
  default     = "ubuntu-22.04"
}

variable "location" {
  description = "Server location (default: hel1)"
  type        = string
  default     = "hel1"
}

variable "ssh_private_key_path" {
  description = "SSH public key file path (default: '~/.ssh/id_rsa')"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "firewall_ids" {
  description = "(Optional) List of firewalls attached to the servers of the cluster"
  type        = list(number)
  default     = []
}

variable "labels" {
  description = "(Optional) Additional labels"
  type        = map(any)
  default     = {}
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"

  validation {
    condition     = can(regex("^1\\.([0-9]+)\\.([0-9]+)$", var.kubernetes_version))
    error_message = "The kubernetes_version value must be a \"1.x.y\"."
  }
}

variable "use_hcloud_network" {
  description = "Use Hetzner private network (default: false)"
  type        = bool
  default     = false
}

variable "hcloud_network_id" {
  description = "(Optional) Hetzner private network ID"
  type        = string
  default     = ""
}

variable "hcloud_subnet_id" {
  description = "(Optional) Hetzner private network ID"
  type        = string
  default     = ""
}
