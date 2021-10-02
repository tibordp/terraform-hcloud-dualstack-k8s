# A simple dual-stack cluster with a single master node

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

  name               = "k8s"
  hcloud_ssh_key     = hcloud_ssh_key.key.id
  hcloud_token       = vars.hetzner_token
  location           = "hel1"
  master_server_type = "cx31"
  worker_server_type = "cx31"
}

// After control plane is set up, additional workers can be joined
// just with user data (can be used for e.g. cluster autoscaler)
resource "hcloud_server" "instance" {
  name        = "additional-worker-node"
  ssh_keys    = [hcloud_ssh_key.key.id]
  image       = "ubuntu-20.04"
  location    = "hel1"
  server_type = "cx31"

  user_data = module.k8s.join_user_data
}


output "simple_kubeconfig" {
  value     = module.k8s.kubeconfig
  sensitive = true
}
