Hetzner Dual-Stack Kubernetes Cluster
=====================================

Unofficial Terraform module to build a basic dual-stack Kubernetes cluster in Hetzner Cloud.

Create a Kubernetes cluster on the [Hetzner cloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs), with the following features:

- Single master node 
- containerd for CRI
- [Cilium](https://cilium.io/) for CNI
  - pods are allocated a private IPv4 address and a public IPv6 from the /64 subnet that Hetzner gives to every node. No masquerading needed for outbound IPv6 traffic!
  - Dual-stack and IPv6-only `Service`s get a private (ULA) IPv6 address
- deploys the [Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) so `LoadBalancer` services provision Hetzner load balancers
- deploys the [Container Storage Interface](https://github.com/hetznercloud/csi-driver) for dynamic provisioning of volumes

# Some important notes

While this module tries to follow Kuberentes best practices, exercise caution before using it in production, as it is not particularly hardened.

- No multi-master/HA control plane support at this point (PRs welcome).
- As pods get a public IPv6 address, the ports they bind are directly exposed to the public internet. If this is not desired, appropriate [Cilium network policy](https://docs.cilium.io/en/v1.10.0-rc1/policy/) or filtered at the edge through Hetzner firewall.
- kubelet serving certificates are self-signed. This can be an issue for metrics-server. See [here](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#kubelet-serving-certs) for some workarounds.

# Getting Started

Configure the Hetzner Cloud provider according to the [documentation](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs) and provide a [Hetzner Cloud SSH key resource](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/ssh_key) to access the cluster machines:

```hcl
resource "hcloud_ssh_key" "key" {
  name       = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}
```

Create a Kubernetes cluster:

```hcl
module "dualstack_cluster" {
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
  value = module.dualstack_cluster.kubeconfig
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
k8s-master     Ready    control-plane,master   31m   v1.21.1
k8s-worker-0   Ready    <none>                 31m   v1.21.1
k8s-worker-1   Ready    <none>                 31m   v1.21.1
```

## Chaining other terraform modules

TLS certificate credentials form the output can be used to chain other Terraform modules, such as the [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs):

```hcl

provider "kubernetes" {
  host = "https://${module.dualstack_cluster.apiserver_ipv4_address}:6443"

  client_certificate     = base64decode(module.dualstack_cluster.client_certificate_data)
  client_key             = base64decode(module.dualstack_cluster.client_key_data)
  cluster_ca_certificate = base64decode(module.dualstack_cluster.client_certificate_data)
}
```

## Acknowledgements 

Some parts, including this README, adapted from [JWDobken/terraform-hcloud-kubernetes](https://github.com/JWDobken/terraform-hcloud-kubernetes) by Joost Döbken.