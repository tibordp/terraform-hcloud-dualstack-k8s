# Hetzner Dual-Stack Kubernetes Cluster

Unofficial Terraform module to build a basic dual-stack Kubernetes cluster in Hetzner Cloud.

Create a Kubernetes cluster on the [Hetzner cloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs), with the following features:

- Single or multiple control plane nodes (in [HA configuration with stacked `etcd`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/))
- containerd for CRI
- [Cilium](https://cilium.io/) for CNI
  - pods are allocated a private IPv4 address and a public IPv6 from the /64 subnet that Hetzner gives to every node. No masquerading needed for outbound IPv6 traffic!
  - Dual-stack and IPv6-only `Service`s get a private (ULA) IPv6 address
  - Wireguard for pod-to-pod traffic encryption (Hetzner [private networks are [not encrypted](https://docs.hetzner.com/cloud/networks/faq/#is-traffic-inside-hetzner-cloud-networks-encrypted))
- deploys the [Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) so `LoadBalancer` services provision Hetzner load balancers
- deploys the [Container Storage Interface](https://github.com/hetznercloud/csi-driver) for dynamic provisioning of volumes

## Some important notes

While this module tries to follow Kuberentes best practices, exercise caution before using it in production, as it is not particularly hardened.

- As pods get a public IPv6 address, the ports they bind are directly exposed to the public internet. If this is not desired, appropriate [Cilium network policy](https://docs.cilium.io/en/v1.10.0-rc1/policy/) or filtered at the edge through Hetzner firewall.
- kubelet serving certificates are self-signed. This can be an issue for metrics-server. See [here](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#kubelet-serving-certs) for some workarounds.
- No cluster autoscaler support as the networking configuration is done in Terraform.
- Limited day-2 operations - changing the number of nodes is possible through Terraform only, but other changes to the cluster will likely result in having to recreate the cluster.

## Getting Started

Configure the Hetzner Cloud provider according to the [documentation](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs) and provide a [Hetzner Cloud SSH key resource](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/ssh_key) to access the cluster machines:

```hcl
resource "hcloud_ssh_key" "key" {
  name       = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}
```

Create a simple Kubernetes cluster:

```hcl
module "k8s" {
  source  = "tibordp/dualstack-k8s/hcloud"

  name               = "k8s"
  hcloud_ssh_key     = hcloud_ssh_key.key.id
  hcloud_token       = var.hetzner_token
  location           = "hel1"
  master_server_type = "cx31"
  worker_server_type = "cx31"
  worker_count       = 2
}

output "kubeconfig" {
  value = module.k8s.kubeconfig
}
```

When the cluster is deployed, the `kubeconfig` to reach the cluster is available from the output. There are many ways to continue, but you can store it to file:

```cmd
terraform output -raw kubeconfig > demo-cluster.conf
```

and check the access by viewing the created cluster nodes:

```cmd
$ kubectl get nodes --kubeconfig=demo-cluster.conf
NAME           STATUS   ROLES                  AGE   VERSION
k8s-master-0   Ready    control-plane,master   31m   v1.21.1
k8s-worker-0   Ready    <none>                 31m   v1.21.1
k8s-worker-1   Ready    <none>                 31m   v1.21.1
```

## High availability setup

This module can create a multi-master setup with a highly available control plane. There are two options available:

- A Hetzner load balancer in front of the control-plane nodes (see [example](./examples/ha_load_balancer.tf))
- External load balancer (or a DNS-based solution). Whatever is specified in `control_plane_endpoint` will be used as a API server endpoint and it is up to you to make sure request are routed to the master nodes  (see [example](./examples/ha_dns_name.tf))

## Chaining other Terraform modules

TLS certificate credentials form the output can be used to chain other Terraform modules, such as the [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs):

```hcl

provider "kubernetes" {
  host = module.k8s.apiserver_url

  client_certificate     = module.k8s.client_certificate_data
  client_key             = module.k8s.client_key_data
  cluster_ca_certificate = module.k8s.certificate_authority_data
}
```

## Acknowledgements 

Some parts, including this README, adapted from [JWDobken/terraform-hcloud-kubernetes](https://github.com/JWDobken/terraform-hcloud-kubernetes) by Joost Döbken.