terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.38"
    }
  }
}

module "node" {
  source = "../kubernetes-node"

  name               = var.name
  hcloud_ssh_key     = var.hcloud_ssh_key
  server_type        = var.server_type
  image              = var.image
  location           = var.location
  kubernetes_version = var.kubernetes_version

  labels       = merge(var.labels, { cluster = var.cluster.name, role = "worker" })
  firewall_ids = var.firewall_ids

  ssh_private_key_path = var.ssh_private_key_path
}

resource "hcloud_server_network" "node_server_network" {
  count = var.use_hcloud_network ? 1 : 0

  server_id = module.node.id
  subnet_id = var.hcloud_subnet_id
}


resource "null_resource" "node_join" {
  triggers = {
    instance_id = module.node.id
  }

  connection {
    host        = module.node.ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      var.cluster.join_command
    ]
  }
}