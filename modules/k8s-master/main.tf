terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.26.0"
    }
  }
}

resource "hcloud_server" "instance" {
  name        = var.name
  ssh_keys    = [var.ssh_key]
  image       = var.image
  location    = var.location
  server_type = var.server_type

  connection {
    host        = hcloud_server.instance.ipv4_address
    timeout     = "5m"
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "file" {
    source      = "${path.module}/../../scripts/prepare-node.sh"
    destination = "/root/prepare-node.sh"
  }

  provisioner "file" {
    source      = "${path.module}/../../scripts/master-init.sh"
    destination = "/root/master-init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/prepare-node.sh /root/master-init.sh",
      "/root/prepare-node.sh",
      "HCLOUD_TOKEN=\"${var.hcloud_token}\" /root/master-init.sh"
    ]
  }
}

module "kubeconfig" {
  source     = "matti/resource/shell"
  depends_on = [hcloud_server.instance]

  trigger = hcloud_server.instance.ipv4_address

  command = <<EOT
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${hcloud_server.instance.ipv4_address} 'cat /root/.kube/config'
  EOT
}