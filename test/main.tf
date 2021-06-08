terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.26.0"
    }
    kubernetes-alpha = {
      source  = "hashicorp/kubernetes-alpha"
      version = "0.4.1"
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

  worker_count = 1
}

module "ha_cluster" {
  source = "./.."

  name               = "ha"
  hcloud_ssh_key     = hcloud_ssh_key.key.id
  hcloud_token       = var.hetzner_token
  location           = "hel1"
  master_server_type = "cx21"
  worker_server_type = "cx21"

  control_plane_lb_type = "lb11"

  worker_count = 1
  master_count = 2
}

provider "kubernetes-alpha" {
  alias = "simple_cluster"
  # GitHub Actions does not have IPv6 connectivity, so we need to use IPv4 :/

}



module "app_simple_cluster" {
  depends_on = [
    module.simple_cluster
  ]

  source = "./modules/http_server"

  host = "https://${module.simple_cluster.masters[0].ipv4_address}:6443"

  client_certificate     = module.simple_cluster.client_certificate_data
  client_key             = module.simple_cluster.client_key_data
  cluster_ca_certificate = module.simple_cluster.certificate_authority_data
}

module "app_ha_cluster" {
  depends_on = [
    module.ha_cluster
  ]

  source = "./modules/http_server"

  host = "https://${module.ha_cluster.load_balancer.ipv4}:6443"

  client_certificate     = module.ha_cluster.client_certificate_data
  client_key             = module.ha_cluster.client_key_data
  cluster_ca_certificate = module.ha_cluster.certificate_authority_data
}
