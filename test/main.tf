terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.38"
    }
  }
}


variable "hetzner_token" {}

provider "hcloud" {
  token = var.hetzner_token
}

resource "hcloud_ssh_key" "key" {
  name       = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}

module "simple_cluster" {
  source = "./.."

  name                      = "simple"
  hcloud_ssh_key            = hcloud_ssh_key.key.id
  hcloud_token              = var.hetzner_token
  location                  = "hel1"
  control_plane_server_type = "cx21"
  worker_server_type        = "cx21"

  worker_count = 1
}

module "ha_cluster" {
  source = "./.."

  name                      = "ha"
  hcloud_ssh_key            = hcloud_ssh_key.key.id
  hcloud_token              = var.hetzner_token
  location                  = "hel1"
  control_plane_server_type = "cx21"
  worker_server_type        = "cx21"

  control_plane_lb_type = "lb11"

  worker_count        = 1
  control_plane_count = 2
}


# GitHub Actions does not support IPv6 connectivity, so we need to hack the server endpoints
output "simple_cluster" {
  value = replace(
    module.simple_cluster.kubeconfig,
    "/server: .*/",
    "server: https://${module.simple_cluster.control_plane_nodes[0].ipv4_address}:6443"
  )
  sensitive = true
}

output "ha_cluster" {
  value = replace(
    module.ha_cluster.kubeconfig,
    "/server: .*/",
    "server: https://${module.ha_cluster.load_balancer.ipv4}:6443"
  )
  sensitive = true
}
