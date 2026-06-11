variable "name" {
  description = "Name of the cluster"
  type        = string
}

variable "hcloud_ssh_key" {
  description = "SSH key name or ID"
  type        = string
}

variable "server_type" {
  description = "Server SKU for control plane nodes (default: 'cpx32')"
  type        = string
  default     = "cpx32"
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

  validation {
    condition     = var.node_count >= 1
    error_message = "At least one control plane node is required."
  }

  validation {
    condition     = var.node_count <= 1 || var.control_plane_endpoint != "" || var.load_balancer_type != ""
    error_message = "Set control_plane_endpoint or load_balancer_type when node_count > 1. It must be set when the cluster is first created; adding it to an existing single-node cluster does not reconfigure the running control plane."
  }
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

variable "use_nftables" {
  description = "Use the nftables backend for kube-proxy and wigglenet (default: true)"
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
  description = "Version of Kubernetes to install (default: 1.36.1)"
  type        = string
  default     = "1.36.1"

  validation {
    condition     = can(regex("^1\\.([0-9]+)\\.([0-9]+)$", var.kubernetes_version))
    error_message = "The kubernetes_version value must be a \"1.x.y\"."
  }
}

variable "ca_key_algorithm" {
  description = "Key algorithm for the cluster CA and service-account signing keys: \"RSA\" or \"ECDSA\". Applied when the cluster is first created; ignored on existing clusters (the PKI is write-once)."
  type        = string
  default     = "RSA"

  validation {
    condition     = contains(["RSA", "ECDSA"], var.ca_key_algorithm)
    error_message = "The ca_key_algorithm value must be \"RSA\" or \"ECDSA\"."
  }
}

variable "ca_rsa_bits" {
  description = "RSA key size for the PKI keys when ca_key_algorithm is \"RSA\" (default: 2048)"
  type        = number
  default     = 2048
}

variable "ca_ecdsa_curve" {
  description = "ECDSA curve for the PKI keys when ca_key_algorithm is \"ECDSA\" (default: P256)"
  type        = string
  default     = "P256"
}

variable "ca_validity_period_hours" {
  description = "Validity of the CA certificates in hours (default: 876000, ~100 years). The CAs are never renewed by Terraform; see caveats."
  type        = number
  default     = 876000
}

variable "use_hcloud_network" {
  description = "Use Hetzner private network (default: false)"
  type        = bool
  default     = false

  validation {
    condition     = !var.use_hcloud_network || (var.hcloud_network_id != "" && var.hcloud_subnet_id != "")
    error_message = "hcloud_network_id and hcloud_subnet_id must be set when use_hcloud_network is true."
  }
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
