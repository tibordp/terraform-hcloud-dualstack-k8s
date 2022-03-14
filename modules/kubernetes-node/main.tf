terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.31"
    }
  }
}

locals {
  provision_scripts = {
    ubuntu = "prepare-debian-like.sh.tpl",
    debian = "prepare-debian-like.sh.tpl",
    centos = "prepare-centos-like.sh.tpl",
    fedora = "prepare-centos-like.sh.tpl",
    rocky  = "prepare-centos-like.sh.tpl",
  }
  provision_script = templatefile("${path.module}/scripts/${local.provision_scripts[data.hcloud_image.image.os_flavor]}", {
    kubernetes_version = var.kubernetes_version
  })
}

data "hcloud_image" "image" {
  name = var.image
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
