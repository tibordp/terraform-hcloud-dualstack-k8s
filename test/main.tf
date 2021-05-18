terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.26.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.2.0"
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

provider "kubernetes" {
  alias = "simple_cluster"
  host  = module.simple_cluster.apiserver_url

  client_certificate     = module.simple_cluster.client_certificate_data
  client_key             = module.simple_cluster.client_key_data
  cluster_ca_certificate = module.simple_cluster.certificate_authority_data
}

provider "kubernetes" {
  alias = "ha_cluster"
  host  = module.ha_cluster.apiserver_url

  client_certificate     = module.ha_cluster.client_certificate_data
  client_key             = module.ha_cluster.client_key_data
  cluster_ca_certificate = module.ha_cluster.certificate_authority_data
}

module "app_simple_cluster" {
  depends_on = [
    module.simple_cluster
  ]

  source = "./modules/http_server"
  providers = {
    kubernetes = kubernetes.simple_cluster
  }
}

module "app_ha_cluster" {
  depends_on = [
    module.ha_cluster
  ]

  source = "./modules/http_server"
  providers = {
    kubernetes = kubernetes.ha_cluster
  }
}

output "ip_address_simple_cluster" {
  value = module.app_simple_cluster.load_balancer_address
}

output "ip_address_ha_cluster" {
  value = module.app_ha_cluster.load_balancer_address
}