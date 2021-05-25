output "id" {
  description = "ID of the node"
  value       = hcloud_server.instance.id
}

output "node_name" {
  description = "Name of the node"
  value       = var.name
}

output "private_ipv4_address" {
  description = "IPv4 address of the server"
  value       = local.private_ipv4_address
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

output "pod_subnet_v6" {
  description = "IPv6 address of the server"
  value       = local.pod_subnet_v6
}

output "pod_subnet_v4" {
  description = "IPv6 network of the server"
  value       = local.pod_subnet_v4
}

output "podcidrs_patch" {
  description = "Pod cidrs patch"
  value = {
    "spec" = {
      "podCIDR" = local.pod_subnet_v6,
      "podCIDRs" = [
        local.pod_subnet_v6,
        local.pod_subnet_v4
      ]
    }
  }
}