output "id" {
  description = "ID of the node"
  value       = hcloud_server.instance.id
}

output "node_name" {
  description = "Name of the node"
  value       = var.name
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