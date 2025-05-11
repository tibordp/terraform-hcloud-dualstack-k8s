# A simple dual-stack cluster with Hetzner Cloud private networks

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50"
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
  server_type    = "cpx31"

  # The default pod_cidr_ipv6 is 10.96.0.0/16. This can be customized,
  # but it should be within the range of the private network. Also, it should
  # not overlap with the subnet specified below, as that subnet is used for nodes.
  # pod_cidr_ipv4 = "10.96.0.0/16"

  use_hcloud_network = true
  hcloud_network_id  = hcloud_network.my_net.id
  hcloud_subnet_id   = hcloud_network_subnet.my_subnet.id
}

module "workers" {
  source = "tibordp/dualstack-k8s/hcloud//modules/worker-node"

  cluster = module.cluster
  count   = 2

  name           = "k8s-worker-${count.index}"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  location       = "hel1"

  server_type = "cpx31"

  use_hcloud_network = true
  hcloud_network_id  = hcloud_network.my_net.id
  hcloud_subnet_id   = hcloud_network_subnet.my_subnet.id
}

resource "hcloud_network" "my_net" {
  name     = "my-net"
  ip_range = "10.0.0.0/8"
}

# This subnet is used for nodes
resource "hcloud_network_subnet" "my_subnet" {
  network_id   = hcloud_network.my_net.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/16"
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}
