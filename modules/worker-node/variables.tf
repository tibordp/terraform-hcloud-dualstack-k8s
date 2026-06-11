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
  description = "Server SKU (default: 'cpx32')"
  type        = string
  default     = "cpx32"
}

variable "image" {
  description = "Image for the nodes (default: ubuntu-24.04)"
  type        = string
  default     = "ubuntu-24.04"
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
  default     = "1.36.1"

  validation {
    condition     = can(regex("^1\\.([0-9]+)\\.([0-9]+)$", var.kubernetes_version))
    error_message = "The kubernetes_version value must be a \"1.x.y\"."
  }
}

variable "use_hcloud_network" {
  description = "Use Hetzner private network (default: false)"
  type        = bool
  default     = false

  validation {
    condition     = !var.use_hcloud_network || var.hcloud_subnet_id != ""
    error_message = "hcloud_subnet_id must be set when use_hcloud_network is true."
  }
}

variable "hcloud_subnet_id" {
  description = "(Optional) Hetzner private network subnet ID"
  type        = string
  default     = ""
}
