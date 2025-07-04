variable "name" {
  description = "Name of the cluster"
  type        = string
}

variable "hcloud_ssh_key" {
  description = "SSH key name or ID"
  type        = string
}

variable "server_type" {
  description = "Server SKU for control plane nodes (default: 'cpx31')"
  type        = string
  default     = "cpx31"
}

variable "hcloud_token" {
  description = "Hetzner token for CCM and storage provisioner"
  type        = string
  sensitive   = true
}

variable "node_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "load_balancer_type" {
  description = "(Optional) Type of the load balancer for control plane nodes"
  type        = string
  default     = ""
}

variable "control_plane_endpoint" {
  description = "(Optional) DNS name for the control plane endpoint"
  type        = string
  default     = ""
}

variable "pod_cidr_ipv4" {
  description = "IPv4 CIDR for Pods"
  type        = string
  default     = "10.96.0.0/16"
}

variable "service_cidr_ipv6" {
  description = "IPv6 CIDR for Services"
  type        = string
  default     = "fd00::/112"
}

variable "service_cidr_ipv4" {
  description = "IPv4 CIDR for Services"
  type        = string
  default     = "172.16.0.0/16"
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

variable "kubeadm_host" {
  description = "(Optional) The control plane node to use for management operations"
  type        = string
  default     = ""
}

variable "apiserver_extra_sans" {
  description = "(Optional) Extra SANs for the apiserver certificate"
  type        = list(any)
  default     = []
}

variable "filter_pod_ingress_ipv6" {
  description = "Filter out ingress IPv6 traffic directed to pods (default: true)"
  type        = bool
  default     = true
}

variable "primary_ip_family" {
  description = "(Optional) Primary IP family for Service resources in cluster (default: ipv6)"
  type        = string
  default     = "ipv6"

  validation {
    condition     = can(regex("^(ipv4|ipv6)$", var.primary_ip_family))
    error_message = "The primary_ip_family value must be a \"ipv6\" or \"ipv4\"."
  }
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to install (default: 1.33.0)"
  type        = string
  default     = "1.33.0"

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
