terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.31"
    }
  }
}

locals {
  provision_script = templatefile("${path.module}/scripts/prepare-node.sh.tpl", {
    kubernetes_version = var.kubernetes_version
  })
}

resource "hcloud_server" "instance" {
  name        = var.name
  ssh_keys    = [var.hcloud_ssh_key]
  image       = var.image
  location    = var.location
  server_type = var.server_type

  firewall_ids = var.firewall_ids
  labels       = var.labels

  lifecycle {
    ignore_changes = [image]
  }

  connection {
    host        = hcloud_server.instance.ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = local.provision_script
    destination = "/root/prepare-node.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/prepare-node.sh",
      "/root/prepare-node.sh",
    ]
  }
}
