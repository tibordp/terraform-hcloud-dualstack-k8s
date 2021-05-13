Hetzner Dual-Stack Kubernetes Cluster
=====================================

Unofficial Terraform module to provide a simple dual-stack Kubernetes cluster in Hetzner Cloud.

Create a Kubernetes cluster on the [Hetzner cloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs), with the following features:

- Single master node
- containerd for CRI
- Cilium for CNI
- Uses ULA IPv6 addresses in the cluster and masquerades them for egress connectivity (yuk). In the future I'd like to tap into Cilium to use the /64 that is allocated to every node for pod IP addresses (dunno if possible) and only use private IPs for Services.
- deploys the [Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) so `LoadBalancer` services provision Hetzner load balancers
- deploys the [Container Storage Interface](https://github.com/hetznercloud/csi-driver) for dynamic provisioning of volumes

# Getting Started

Configure the Hetzner Cloud provider according to the [documentation](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs) and provide a [Hetzner Cloud SSH key resource](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/ssh_key) to access the cluster machines:

```hcl
resource "hcloud_ssh_key" "key" {
  name       = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}
```

Create a Kubernetes cluster:

```
module "dualstack_cluster" {
  source = "./.."

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
NAME       STATUS   ROLES    AGE   VERSION
master-1   Ready    master   95s   v1.18.9
worker-1   Ready    <none>   72s   v1.18.9
worker-2   Ready    <none>   73s   v1.18.9
worker-3   Ready    <none>   73s   v1.18.9
```

## Acknowledgements 

Some parts, including this README adapted from [JWDobken/terraform-hcloud-kubernetes](https://github.com/JWDobken/terraform-hcloud-kubernetes)