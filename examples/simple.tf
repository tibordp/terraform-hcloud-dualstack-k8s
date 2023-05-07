# A simple dual-stack cluster with a single control_plane node

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.31.1"
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

module "k8s" {
  source = "tibordp/dualstack-k8s/hcloud"

  name                      = "k8s"
  hcloud_ssh_key            = hcloud_ssh_key.key.id
  hcloud_token              = vars.hetzner_token
  location                  = "hel1"
  control_plane_server_type = "cx31"
  worker_server_type        = "cx31"
  worker_count              = 2
}

output "simple_kubeconfig" {
  value     = module.k8s.kubeconfig
  sensitive = true
}
