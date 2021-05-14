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

output "pod_cidrs" {
  description = "Pod cidrs configuration"
  value = {
    "podCIDR" = cidrsubnet(hcloud_server.instance.ipv6_network, 16, 1),
    "podCIDRs" = [
      cidrsubnet(hcloud_server.instance.ipv6_network, 16, 1),
      cidrsubnet("10.0.0.0/8", 10, var.v4_subnet_index)
    ]
  }
}