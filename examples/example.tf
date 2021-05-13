terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.26.0"
    }
  }
}

locals {
  hetzner_token = "<token>"
}

provider "hcloud" {
  token = local.hetzner_token
}

resource "hcloud_ssh_key" "key" {
  name       = "philomena"
  public_key = file("~/.ssh/id_rsa.pub")
}

module "dualstack_cluster" {
  source = "./.."

  name               = "k8s"
  ssh_key            = hcloud_ssh_key.key.id
  hcloud_token       = local.hetzner_token
  location           = "hel1"
  master_server_type = "cx31"
  worker_server_type = "cx31"
  worker_count       = 2
}

output "kubeconfig" {
  value = module.dualstack_cluster.kubeconfig
}
