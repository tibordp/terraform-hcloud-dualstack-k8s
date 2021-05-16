terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.26.0"
    }
  }
}

locals {
  pod_subnet_v4 = cidrsubnet("10.0.0.0/8", 10, var.node_index + 1)
  pod_subnet_v6 = cidrsubnet(hcloud_server.instance.ipv6_network, 16, 1)
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
    source      = "${path.module}/scripts/bootstrap.sh"
    destination = "/root/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/bootstrap.sh",
      "/root/bootstrap.sh",
    ]
  }
}