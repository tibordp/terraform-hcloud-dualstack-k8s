# A dual-stack cluster with a highly-available control plane using a
# Hetzner Cloud load balancer.

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

module "ha_cluster" {
  source = "tibordp/dualstack-k8s/hcloud"

  name                      = "k8s"
  hcloud_ssh_key            = hcloud_ssh_key.key.id
  hcloud_token              = var.hetzner_token
  location                  = "hel1"
  control_plane_server_type = "cx31"
  worker_server_type        = "cx31"

  worker_count        = 3
  control_plane_count = 3

  control_plane_lb_type = "lb11"
}

output "load_balancer_ipv4" {
  value = module.k8s.load_balancer.ipv4
}

output "load_balancer_ipv6" {
  value = module.k8s.load_balancer.ipv6
}

output "ha_cluster_kubeconfig" {
  value     = module.k8s.kubeconfig
  sensitive = true
}
