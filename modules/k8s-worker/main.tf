terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.26.0"
    }
  }
}

module "join_command" {
  source = "matti/resource/shell"

  depends_on = [var.master_ip_address]

  command = <<EOT
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${var.master_ip_address} 'kubeadm token create $(kubeadm token generate) --print-join-command --ttl=60m'
  EOT
}

resource "hcloud_server" "instance" {
  name        = var.name
  ssh_keys    = [var.hcloud_ssh_key]
  image       = var.image
  location    = var.location
  server_type = var.server_type

  connection {
    host        = hcloud_server.instance.ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = module.join_command.stdout
    destination = "/root/join.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../scripts/prepare-node.sh"
    destination = "/root/prepare-node.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/prepare-node.sh /root/join.sh",
      "/root/prepare-node.sh",
      "/root/join.sh"
    ]
  }
}