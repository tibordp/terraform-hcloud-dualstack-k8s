# A dual-stack cluster with a highly-available control plane using a
# Hetzner Cloud load balancer.

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50"
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

module "cluster" {
  source = "tibordp/dualstack-k8s/hcloud"

  name           = "k8s"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  hcloud_token   = var.hetzner_token
  location       = "nbg1"
  server_type    = "cpx31"
  node_count     = 3

  control_plane_endpoint = "k8s.example.com"
}

module "workers" {
  source = "tibordp/dualstack-k8s/hcloud//modules/worker-node"

  cluster = module.cluster
  count   = 3

  name           = "k8s-worker-${count.index}"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  location       = "nbg1"

  server_type = "cpx31"
}

output "load_balancer_ipv4" {
  value = module.cluster.load_balancer.ipv4
}

output "load_balancer_ipv6" {
  value = module.cluster.load_balancer.ipv6
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}
