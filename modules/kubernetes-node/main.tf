terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.26.0"
    }
  }
}

/*

Subnetting plan for IPv4. Fixed cluster CIDR of 10.0.0.0/8

  8 bits - 10.x.x.x. prefix 
  4 bits for pool index (16 pools)
  10 bits for node index (1024 nodes per pool)
  10 bits for pod index (1024 pods per node)

Currently only two pools are used:
  0 - reserved
  1 - master nodes
  2 - worker nodes

First IP in each node subnet is a private address of the node itself (not really used,
but useful for pinging nodes wia the Wiregard tunnel)

For IPv6, every node just uses the 2nd /80 of its own public /64.

*/


locals {
  pod_subnet_v4 = cidrsubnet(
    cidrsubnet("10.0.0.0/8", 4, var.pool_index),
    10, var.node_index
  )
  pod_subnet_v6        = cidrsubnet(hcloud_server.instance.ipv6_network, 16, 1)
  private_ipv4_address = cidrhost(local.pod_subnet_v4, 1)
}

resource "hcloud_server" "instance" {
  name        = var.name
  ssh_keys    = [var.hcloud_ssh_key]
  image       = var.image
  location    = var.location
  server_type = var.server_type

  firewall_ids = var.firewall_ids
  labels       = var.labels

  connection {
    host        = hcloud_server.instance.ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    source      = "${path.module}/scripts/prepare-node.sh"
    destination = "/root/prepare-node.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/prepare-node.sh",
      "/root/prepare-node.sh",
    ]
  }
}