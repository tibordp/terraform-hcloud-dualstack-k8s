output "id" {
  description = "ID of the node"
  value       = hcloud_server.instance.id
}

output "ipv4_address" {
  description = "IPv4 address of the server"
  value       = hcloud_server.instance.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 address of the server"
  value       = hcloud_server.instance.ipv6_address
}

output "ipv6_network" {
  description = "IPv6 network of the server"
  value       = hcloud_server.instance.ipv6_network
}

output "pod_cidrs" {
  description = "Per-node pod CIDR configuration"
  value = {
    "podCIDR" = local.pod_subnet_v6
    "podCIDRs" = [
      local.pod_subnet_v6,
      local.pod_subnet_v4
    ]
  }
}