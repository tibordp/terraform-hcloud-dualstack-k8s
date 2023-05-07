# A simple dual-stack cluster with a single control_plane node

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
  token = vars.hetzner_token
}

resource "hcloud_ssh_key" "key" {
  name       = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}

module "cluster" {
  source = "tibordp/dualstack-k8s/hcloud"

  name           = "k8s"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  hcloud_token   = vars.hetzner_token
  location       = "hel1"
  server_type    = "cx31"
}

module "workers" {
  source = "tibordp/dualstack-k8s/hcloud//modules/worker-node"

  cluster = module.cluster
  count   = 2

  name           = "k8s-worker-${count.index}"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  location       = "hel1"

  server_type = "cx31"
}

output "simple_kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}
