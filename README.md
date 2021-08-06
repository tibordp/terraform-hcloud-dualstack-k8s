# Hetzner Dual-Stack Kubernetes Cluster

Unofficial Terraform module to build a viable dual-stack Kubernetes cluster in Hetzner Cloud.

Creates a Kubernetes cluster on the [Hetzner cloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs), with the following features:

- Single or multiple control plane nodes (in [HA configuration with stacked `etcd`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/))
- containerd for container runtime
- [Wigglenet](https://github.com/tibordp/wigglenet) for the network plugin
  - the primary address family for the cluster is configurable, but defaults to IPv6, which is used for control plane communication
  - pods are allocated a private IPv4 address and a public IPv6 from the /64 subnet that Hetzner gives to every node. No masquerading needed for outbound IPv6 traffic! 🎉 (stateful firewall rules are still in place, so direct ingress traffic to pods is blocked by default, prefer to expose workloads through Service)
  - Dual-stack and IPv6-only `Service`s get a private (ULA) IPv6 address
  - A full-mesh dynamic overlay network using Wireguard, so pod-to-pod traffic is encrypted (Hetzner private networks [are not encrypted](https://docs.hetzner.com/cloud/networks/faq#is-traffic-inside-hetzner-cloud-networks-encrypted), just segregated)
- deploys the [Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) so `LoadBalancer` services provision Hetzner load balancers and deleted nodes are cleaned up.
- deploys the [Container Storage Interface](https://github.com/hetznercloud/csi-driver) for dynamic provisioning of volumes
- supports dynamic worker node provisioning with cloud-init e.g. for use with [cluster autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/hetzner)

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
  version = "0.6.4"

  name               = "k8s"
  hcloud_ssh_key     = hcloud_ssh_key.key.id
  hcloud_token       = var.hetzner_token
  location           = "hel1"
  master_server_type = "cx31"
  worker_server_type = "cx31"
  worker_count       = 2

  kubernetes_version = "1.22.0"
}

output "kubeconfig" {
  value = module.k8s.kubeconfig
}
```

When the cluster is deployed, the `kubeconfig` to reach the cluster is available from the output. There are many ways to continue, but you can store it to file:

```cmd
terraform output -raw kubeconfig > kubeconfig.conf
```

and check the access by viewing the created cluster nodes:

```cmd
$ kubectl get nodes --kubeconfig=kubeconfig.conf
NAME           STATUS   ROLES                  AGE   VERSION
k8s-master-0   Ready    control-plane,master   31m   v1.22.0
k8s-worker-0   Ready    <none>                 31m   v1.22.0
k8s-worker-1   Ready    <none>                 31m   v1.22.0
```

## High availability setup

This module can create a multi-master setup with a highly available control plane. There are two options available:

- A Hetzner load balancer in front of the control-plane nodes (see [example](./examples/ha_load_balancer.tf))
- External load balancer (or a DNS-based solution). Whatever is specified in `control_plane_endpoint` will be used as a API server endpoint and it is up to you to make sure request are routed to the master nodes  (see [example](./examples/ha_dns_name.tf))

It is recommended to set up `control_plane_endpoint` (e.g. a DNS record) even if a single master node is used, as doing so will allow for additional master nodes to be added later. If this is not done, the
cluster will have to be manually reconfigured (e.g [like this](https://blog.scottlowe.org/2019/08/12/converting-kubernetes-to-ha-control-plane/)) to use the new endpoint when new master nodes are added.

### Removing/replacing master nodes

A first step before removing a control plane node is to remove its membership in the `etcd` cluster. **Read this section carefully before removing master nodes! If etcd membership is not removed from the prior to the node being shutdown, the whole cluster can potentially become inoperable.** If the master node that is being removed is still functional, the easiest way to remove is by invoking the following command on the node:

```cmd
kubeadm reset --force
```

If the node is already defunct, there are two cases to consider:

- etcd cluster still has quorum (i.e. N/2+1 nodes are still functional), the membership of the defunct member can be manually removed with `etcdctl`, e.g.:
  ```
  $ kubectl exec -n kube-system etcd-surviving-master-node -- etcdctl \
      --endpoints=https://[::1]:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key member list
  2a51630843ac2da6, started, defunct-master-node, https://[2a01:db8:2::1]:2380, https://[2a01:db8:2::1]:2379, false
  7f196e4d62a04497, started, surviving-master-node, https://[2a01:db8:1::1]:2380, https://[2a01:db8:1::1]:2379, false

  $ kubectl exec -n kube-system etcd-surviving-master-node -- etcdctl \
      --endpoints=https://[::1]:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key member remove 2a51630843ac2da6
  Member 2a51630843ac2da6 removed from cluster 46b13f81dcebb93d
  ```

  It is important to remove failed members from etcd even if quorum is still present as new master nodes will not be able to join until etcd cluster is healthy.

- etcd cluster no longer has quorum, e.g. a single master node is gone out of a 2-node cluster. In this case the etcd cluster will need to be rebuilt from snapshot, following the steps for [disaster recovery](https://etcd.io/docs/v3.4/op-guide/recovery/). Data loss may have occured.


You may also need to manually remove the Node object, as the Hetzner Cloud Controller that is responsible for deleting defunct nodes may have been running on this very node (should not be an issue if `kubectl drain` was done first)

```
kubectl delete node <node name>
```

First master node is special in that it is used by the provisioning process (e.g. to get the bootstrap tokens for other nodes). If the first node is deleted, another server must be specified, otherwise provisioning operations will fail.

```hcl
module "k8s" {
  source  = "tibordp/dualstack-k8s/hcloud"
  version = "0.6.4"

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
  
  # For a single-master cluster, this will be an IPv6 URL. For IPv4, this can
  # also be used
  # host = "https://${module.k8s.masters[0].ipv4_address}:6443"

  client_certificate     = module.k8s.client_certificate_data
  client_key             = module.k8s.client_key_data
  cluster_ca_certificate = module.k8s.certificate_authority_data
}
```

## Cloud-init script for joining additional worker nodes

Once control plane is set up, module has an output called `join_user_data` that contains a cloud-init script that
can be used to join additional worker nodes outside of Terraform (e.g. for use with [cluster autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/hetzner)).

The generated join configuration will be valid for 10 years, after which the bootstrap token will need to be regenerated (but you should probably rebuild the cluster with something better by then).

See [example](./examples/cloud_init.tf) for how it can be used to manage worker separately from this module.

## Caveats

Read these notes carefully before using this module in production.

- Control plane services that use host networking, such as etcd, kubelet and api-server bind on a public IP. This is not a problem per se since these components all use mTLS for communication, but appropriate Hetzner Firewall rules can be added (make sure to allow UDP port 24601 for Wireguard node-to-node tunnels)
- Wigglenet is an experimental network plugin that I wrote for my personal use and has definitely not been battle tested. `NetworkPolicy` is not supported.
- kubelet serving certificates are self-signed. This can be an issue for metrics-server. See [here for details and workarounds](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#kubelet-serving-certs).
- Some restrictions on day-2 operations. The following are supported seamlessly, but other changes will likely require the manual steps:
   - Node replacement (see notes above for control plane nodes)
   - Vertical scaling of node (changing the server type)
   - Horizontal scaling (changing node count).
   - Changing cluster addons settings (Wigglenet firewall settings, Hetzner API token for the Hetzner CCM and CSI).
- As kube-proxy is configured to use IPVS mode, `load-balancer.hetzner.cloud/hostname: <hostname>` must be set on all `LoadBalancer` services, otherwise healthchecks will fail and the service will not be accessible from outsie the cluster (see [this issue](https://github.com/kubernetes/kubernetes/issues/79783) for more details)

In addition some caveats for dual-stack clusters in general:

- `Services` are single-stack by default. Since IPv6 is the primary IP family of the clusters created with this modules, this means the `ClusterIP` will be IPv6 only, leading to issues for workloads that only bind on IPv4. Pass `ipFamilyPolicy: PreferDualStack` when creating services to assign both IPv4 and IPv6 ClusterIPs. You can use the [prefer-dual-stack-webhook](https://github.com/tibordp/prefer-dual-stack-webhook) admission controller to change the default to `PreferDualStack` for all newly creted services that don't specify IP family policy.
- the apiserver Service (`kubernetes.default.svc.cluster.local`) has to be single-stack, as `--apiserver-advertise-address` does not support dual-stack yet. The default address family for the cluster can be selected with `primary_ip_family` variable (defaults to `ipv6`).


## Acknowledgements 

Some parts, including this README, adapted from [JWDobken/terraform-hcloud-kubernetes](https://github.com/JWDobken/terraform-hcloud-kubernetes) by Joost Döbken.
