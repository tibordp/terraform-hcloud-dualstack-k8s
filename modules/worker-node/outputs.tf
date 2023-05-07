output "id" {
  description = "ID of the node"
  value       = module.node.id
}

output "node_name" {
  description = "Name of the node"
  value       = module.node.node_name
}

output "ipv4_address" {
  description = "IPv4 address of the server"
  value       = module.node.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 address of the server"
  value       = module.node.ipv6_address
}

output "ipv6_network" {
  description = "IPv6 network of the server"
  value       = module.node.ipv6_network
}