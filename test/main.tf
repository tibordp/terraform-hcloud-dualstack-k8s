terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.26.0"
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

  name               = "simple"
  hcloud_ssh_key     = hcloud_ssh_key.key.id
  hcloud_token       = var.hetzner_token
  location           = "hel1"
  master_server_type = "cx21"
  worker_server_type = "cx21"

  master_count = 1
  worker_count = 2
}

module "ha_cluster" {
  source = "./.."

  name               = "ha"
  hcloud_ssh_key     = hcloud_ssh_key.key.id
  hcloud_token       = var.hetzner_token
  location           = "hel1"
  master_server_type = "cx21"
  worker_server_type = "cx21"

  master_count = 2
  worker_count = 2
}

output "simple_cluster_kubeconfig" {
  value = module.simple_cluster.kubeconfig
}

output "ha_cluster_kubeconfig" {
  value = module.ha_cluster.kubeconfig
}

