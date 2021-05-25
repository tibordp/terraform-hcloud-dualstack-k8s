terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.26.0"
    }
  }
}

locals {
  all_nodes = concat(module.master, module.worker)
}