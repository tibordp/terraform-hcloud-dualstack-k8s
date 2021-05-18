terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.26.0"
    }
  }
}

locals {
  pod_subnet_v4        = cidrsubnet("10.0.0.0/8", 10, var.node_index + 1)
  pod_subnet_v6        = cidrsubnet(hcloud_server.instance.ipv6_network, 16, 1)
  private_ipv4_address = cidrhost("10.0.0.0/8", var.node_index + 2)
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

module "wireguard_public_key" {
  source = "matti/resource/shell"

  trigger = hcloud_server.instance.id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     root@${hcloud_server.instance.ipv4_address} 'cat /etc/wg_pub.key'
  EOT
}