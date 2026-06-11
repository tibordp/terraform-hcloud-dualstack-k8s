terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50"
    }
  }
}

variable "hetzner_token" {
  type = string
}

provider "hcloud" {
  token = var.hetzner_token
}

resource "hcloud_ssh_key" "key" {
  name       = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}

locals {
  clusters = {
    simple = {
      node_count         = 1
      load_balancer_type = ""
    }
    ha = {
      node_count         = 2
      load_balancer_type = "lb11"
    }
  }
}

module "cluster" {
  source   = "./.."
  for_each = local.clusters

  name           = each.key
  hcloud_ssh_key = hcloud_ssh_key.key.id
  hcloud_token   = var.hetzner_token
  location       = "hel1"
  server_type    = "cpx22"

  node_count         = each.value.node_count
  load_balancer_type = each.value.load_balancer_type
}

module "worker_node" {
  source   = "./../modules/worker-node"
  for_each = module.cluster

  cluster = each.value

  name           = "${each.key}-worker"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  location       = "hel1"
  server_type    = "cpx22"
}

# GitHub Actions runners have no IPv6 connectivity, so point each kubeconfig at
# the cluster's IPv4 endpoint (the load balancer if there is one, node 0 otherwise).
output "kubeconfigs" {
  value = {
    for name, cluster in module.cluster :
    name => replace(
      cluster.kubeconfig,
      "/server: .*/",
      "server: https://${try(cluster.load_balancer.ipv4, cluster.control_plane_nodes[0].ipv4_address)}:6443"
    )
  }
  sensitive = true
}
