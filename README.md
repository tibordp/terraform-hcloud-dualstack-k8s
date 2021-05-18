# Hetzner Dual-Stack Kubernetes Cluster

Unofficial Terraform module to build a basic dual-stack Kubernetes cluster in Hetzner Cloud.

Create a Kubernetes cluster on the [Hetzner cloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs), with the following features:

- Single or multiple control plane nodes (in [HA configuration with stacked `etcd`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/))
- containerd for CRI
- IPv6 control plane communication
- A [custom "network plugin"](./templates/cni.json.tpl), because all major network plugins are broken in various ways for dual-stack.
  - pods are allocated a private IPv4 address and a public IPv6 from the /64 subnet that Hetzner gives to every node. No masquerading needed for outbound IPv6 traffic!
  - Dual-stack and IPv6-only `Service`s get a private (ULA) IPv6 address
  - A full-mesh static overlay network using Wireguard (pod-to-pod traffic is encrypted)  
- deploys the [Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) so `LoadBalancer` services provision Hetzner load balancers and deleted nodes are cleaned up.
- deploys the [Container Storage Interface](https://github.com/hetznercloud/csi-driver) for dynamic provisioning of volumes

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

It is recommended to set up `control_plane_endpoint` (e.g. a DNS record) even if a single master node is used, as doing so will allow for additional master nodes to be added later. If this is not done, the
cluster will have to be manually reconfigured (e.g [like this](https://blog.scottlowe.org/2019/08/12/converting-kubernetes-to-ha-control-plane/)) to use the new endpoint when new master nodes are added.

### Removing/replacing master nodes

A first step before removing a control plane node is to remove it from the `etcd` cluster.
If the node is still operational, the easiest way to do it is with `kubeadm`. Otherwise, it will have to be done manually with `etcdctl`. This is very important! If not done, new nodes will not be able to join, even if the `etcd` cluster has quorum.

```cmd
kubeadm reset --force
```

You may also need to manually remove the node, as the Hetzner Cloud Controller that is responsible for deleting defunct nodes may have been running on this very node (should not be an issue if `kubectl drain` was done first)

```
kubectl delete node <node name>
```

First master node is special in that it is used by the provisioning process (e.g. to get the bootstrap tokens for other nodes). If the first node is deleted, another server must be specified, otherwise provisioning operations will fail.

```hcl
module "k8s" {
  source  = "tibordp/dualstack-k8s/hcloud"
 
  ...
 
  kubeadm_host = "<ip address of another master node>"
}
```

Afterwards, the node can be replaced as usual, e.g.

```
terraform taint module.k8s.module.master[0].hcloud_server.instance
terraform apply
```


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

## Caveats

Exercise caution before using this module in production, as it is not particularly hardened.

- As pods get a public IPv6 address, the ports they bind are directly exposed to the public internet. This can be mitigated by attaching a Hetzner Cloud Firewall (which is a stateful firewall). Pod-to-pod communication is done through an encrypted tunnel (UDP port 51820), so other ingress IPv6 to pod subnets can safely be blocked at the edge without interfering with internal traffic.
- In a similar fashion, control plane services that use host networking, such as etcd, kubelet and api-server bind on a public IP. This is not a problem per se since these components all use mTLS for communication
- No `NetworkPolicy` support (if you can make it work, please let me know!)
- kubelet serving certificates are self-signed. This can be an issue for metrics-server. See [here](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#kubelet-serving-certs) for some workarounds.
- Some restrictions on day-2 operations. The following are supported seamlessly, but other changes will likely require the cluster to be recreated (or replaced node-by-node):
   - Node replacement (see notes below for control plane nodes)
   - Vertical scaling of node (changing the server type)
   - Horizontal scaling (changing node count) of both master and worker nodes.
- No cluster autoscaler support as the networking setup is statically performed in Terraform.

## Acknowledgements 

Some parts, including this README, adapted from [JWDobken/terraform-hcloud-kubernetes](https://github.com/JWDobken/terraform-hcloud-kubernetes) by Joost Döbken.