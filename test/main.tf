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

  name           = "simple"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  hcloud_token   = var.hetzner_token
  location       = "hel1"
  server_type    = "cx21"

  worker_count = 1
}

module "simple_worker_node" {
  source = "./../modules/worker-node"

  cluster = module.simple_cluster

  name           = "simple-worker"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  location       = "hel1"

  server_type = "cx21"
}

module "ha_cluster" {
  source = "./.."

  name           = "ha"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  hcloud_token   = var.hetzner_token
  location       = "hel1"
  server_type    = "cx21"

  load_balancer_type = "lb11"

  node_count = 2
}

module "ha_worker_node" {
  source = "./../modules/worker-node"

  cluster = module.ha_cluster

  name           = "ha-worker"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  location       = "hel1"

  server_type = "cx21"
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
