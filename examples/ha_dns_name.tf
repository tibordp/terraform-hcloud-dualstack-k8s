# This example sets up a HA control plane with DNS-based routing.

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.31.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

variable "hetzner_token" {}

provider "aws" {
  region = "eu-west-1"
}

provider "hcloud" {
  token = var.hetzner_token
}

resource "hcloud_ssh_key" "key" {
  name       = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Create a server

module "k8s" {
  source = "tibordp/dualstack-k8s/hcloud"

  name               = "k8s"
  hcloud_ssh_key     = hcloud_ssh_key.key.id
  hcloud_token       = var.hetzner_token
  location           = "nbg1"
  master_server_type = "cpx31"
  worker_server_type = "cpx31"

  worker_count = 3
  master_count = 3

  control_plane_endpoint = "k8s.example.com"
}

resource "aws_route53_record" "api_server_aaaa" {
  name    = "k8s.example.com"
  records = module.k8s.masters.*.ipv6_address
  ttl     = "60"
  type    = "AAAA"
  zone_id = "<zone id>"
}

resource "aws_route53_record" "api_server_a" {
  name    = "k8s.example.com"
  records = module.k8s.masters.*.ipv4_address
  ttl     = "60"
  type    = "A"
  zone_id = "<zone id>"
}

output "kubeconfig" {
  value     = module.k8s.kubeconfig
  sensitive = true
}
