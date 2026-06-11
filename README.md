# Hetzner Dual-Stack Kubernetes Cluster

Unofficial Terraform module to build a viable dual-stack Kubernetes cluster in Hetzner Cloud.

Creates a Kubernetes cluster on the [Hetzner Cloud](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs), with the following features:

- Single or multiple control plane nodes (in [HA configuration with stacked `etcd`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/))
- containerd as the container runtime
- [Wigglenet](https://github.com/tibordp/wigglenet) for the network plugin
  - the primary address family for the cluster is configurable, but defaults to IPv6, which is used for control plane communication
  - pods are allocated a private IPv4 address and a public IPv6 from the /64 subnet that Hetzner gives to every node. No masquerading needed for outbound IPv6 traffic! 🎉 (stateful firewall rules are still in place, so direct ingress traffic to pods is blocked by default; prefer exposing workloads through a `Service`)
  - Dual-stack and IPv6-only `Service`s get a private (ULA) IPv6 address
  - A full-mesh dynamic overlay network using Wireguard, so pod-to-pod traffic is encrypted
- deploys the [Hetzner Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) so `LoadBalancer` services provision Hetzner load balancers and deleted nodes are cleaned up
- deploys the [Container Storage Interface](https://github.com/hetznercloud/csi-driver) for dynamic provisioning of volumes
- supports dynamic worker node provisioning with cloud-init e.g. for use with [cluster autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/hetzner)
- supports multiple worker node pools with different machine types

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
module "cluster" {
  source  = "tibordp/dualstack-k8s/hcloud"
  version = "3.0.0"

  name           = "k8s"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  hcloud_token   = var.hetzner_token
  location       = "hel1"
}

module "worker_nodes" {
  source  = "tibordp/dualstack-k8s/hcloud//modules/worker-node"
  version = "3.0.0"

  cluster = module.cluster
  count   = 2

  name           = "k8s-worker-${count.index}"
  hcloud_ssh_key = hcloud_ssh_key.key.id
  location       = "hel1"
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}
```

When the cluster is deployed, the `kubeconfig` to reach the cluster is available from the output. There are many ways to continue, but you can store it to a file:

```cmd
terraform output -raw kubeconfig > kubeconfig.conf
```

and check access by listing the cluster nodes:

```cmd
$ kubectl get nodes --kubeconfig=kubeconfig.conf
NAME                  STATUS   ROLES           AGE   VERSION
k8s-control-plane-0   Ready    control-plane   31m   v1.36.1
k8s-worker-0          Ready    <none>          31m   v1.36.1
k8s-worker-1          Ready    <none>          31m   v1.36.1
```

## Supported base images

The module should work on most major RPM and DEB distros. It has been tested on these base images:

- Ubuntu 24.04 (`ubuntu-24.04`)
- Ubuntu 26.04 (`ubuntu-26.04`)
- Debian 13 (`debian-13`)
- Fedora 44 (`fedora-44`)

Others may work as well, but have not been tested.

## High availability setup

This module can create a highly available control plane with multiple control plane nodes. There are two options available:

- A Hetzner load balancer in front of the control-plane nodes (see [example](./examples/ha_load_balancer.tf))
- External load balancer (or a DNS-based solution). Whatever is specified in `control_plane_endpoint` will be used as the API server endpoint and it is up to you to make sure requests are routed to the control plane nodes (see [example](./examples/ha_dns_name.tf))

It is recommended to set up `control_plane_endpoint` (e.g. a DNS record) even if a single control plane node is used, as doing so will allow for additional control plane nodes to be added later. If this is not done, the
cluster will have to be manually reconfigured (e.g [like this](https://blog.scottlowe.org/2019/08/12/converting-kubernetes-to-ha-control-plane/)) to use the new endpoint when new control plane nodes are added.

### Removing/replacing control plane nodes

A first step before removing a control plane node is to remove its membership in the `etcd` cluster. **Read this section carefully before removing control plane nodes! If etcd membership is not removed prior to the node being shut down, the whole cluster can potentially become inoperable.** If the control plane node that is being removed is still functional, the easiest way to remove it is to run the following command on the node:

```cmd
kubeadm reset --force
```

If the node is already defunct, there are two cases to consider:

- If the etcd cluster still has quorum (i.e. N/2+1 nodes are still functional), the membership of the defunct member can be removed manually with `etcdctl`, e.g.:
  ```
  $ kubectl exec -n kube-system etcd-surviving-control-plane-node -- etcdctl \
      --endpoints=https://[::1]:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key member list
  2a51630843ac2da6, started, defunct-control-plane-node, https://[2a01:db8:2::1]:2380, https://[2a01:db8:2::1]:2379, false
  7f196e4d62a04497, started, surviving-control-plane-node, https://[2a01:db8:1::1]:2380, https://[2a01:db8:1::1]:2379, false

  $ kubectl exec -n kube-system etcd-surviving-control-plane-node -- etcdctl \
      --endpoints=https://[::1]:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key member remove 2a51630843ac2da6
  Member 2a51630843ac2da6 removed from cluster 46b13f81dcebb93d
  ```

  It is important to remove failed members from etcd even if quorum is still present, as new control plane nodes will not be able to join until the etcd cluster is healthy.

- If the etcd cluster no longer has quorum, e.g. a single control plane node is gone out of a 2-node cluster, the etcd cluster will need to be rebuilt from snapshot, following the steps for [disaster recovery](https://etcd.io/docs/v3.6/op-guide/recovery/). Data loss may have occurred.


You may also need to manually remove the Node object, as the Hetzner Cloud Controller that is responsible for deleting defunct nodes may have been running on this very node (should not be an issue if `kubectl drain` was done first)

```
kubectl delete node <node name>
```

No control plane node is special to the provisioning process: the cluster CA and the bootstrap token are generated by Terraform, and joining nodes discover the cluster through `control_plane_endpoint`. Any control plane node, including the first, can be replaced by recreating its server — as long as `control_plane_endpoint` resolves to a surviving node (so set it to a load balancer or DNS record before you need to replace nodes). After removing the dead node's `etcd` membership as described above, replace the server:

```
terraform apply -replace='module.cluster.module.control_plane[0].hcloud_server.instance'
```

## Chaining other Terraform modules

The TLS client credentials from the outputs can be used to chain other Terraform modules, such as the [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs):

```hcl
provider "kubernetes" {
  host = module.cluster.apiserver_url

  # For a single control plane node cluster, this will be an IPv6 URL. For IPv4, this can
  # also be used
  # host = "https://${module.cluster.control_plane_nodes[0].ipv4_address}:6443"

  client_certificate     = module.cluster.client_certificate_data
  client_key             = module.cluster.client_key_data
  cluster_ca_certificate = module.cluster.certificate_authority_data
}
```

## Cloud-init script for joining additional worker nodes

Once the control plane is set up, the module has an output called `join_user_data` that contains a cloud-init script that
can be used to join additional worker nodes outside of Terraform (e.g. for use with [cluster autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/hetzner)).

The bootstrap token embedded in the join configuration is created without a TTL, so the generated configuration does not expire and remains valid for the life of the cluster.

See [example](./examples/cloud_init.tf) for how it can be used to manage workers separately from this module.

## Using Hetzner Cloud private networks

This module can be configured to use Hetzner Cloud private networks by specifying `use_hcloud_network`, `hcloud_network_id` and `hcloud_subnet_id` variables. In this case native routing will be used for IPv4 traffic and Wigglenet overlay will only be used for IPv6 traffic (Hetzner private networks are IPv4-only). Note that Hetzner private networks [are not encrypted](https://docs.hetzner.com/cloud/networks/faq#is-traffic-inside-hetzner-cloud-networks-encrypted), just segregated.

See [example](./examples/private_network.tf) for more details.

## Caveats

Read these notes carefully before using this module in production.

- The cluster PKI — the CA certificates and keys, and the service-account signing key — is generated by Terraform and held in the state, then distributed to control plane nodes over SSH. This is what makes provisioning fully declarative and removes the need to copy certificates between nodes, but it also means **your Terraform state holds the cluster's root of trust**. Use a remote state backend with encryption and access control, and back it up: losing the state means losing the CA, and anyone who can read it can mint credentials for the cluster. The CA is generated once and never rotated by Terraform (it is the equivalent of a `random_id`); kubeadm signs and renews all leaf certificates from it on the nodes. The key algorithm (`ca_key_algorithm`, `ca_rsa_bits`/`ca_ecdsa_curve`) and certificate validity (`ca_validity_period_hours`) are set at cluster creation and then frozen — changing them later only affects newly-created clusters.
- The CA certificates default to ~100 years of validity (`ca_validity_period_hours`). There is no early renewal, so Terraform leaves them untouched for that entire window. **Once a CA certificate actually expires, Terraform will plan to regenerate it** (the `tls` provider treats an expired certificate as ready for renewal and forces replacement — this is driven by the recorded validity, not by `ignore_changes`, which cannot suppress it). In practice this is academic at the default validity, and an expired cluster CA is a far larger operational problem than a Terraform state diff — but if you lower `ca_validity_period_hours`, be aware that a plan run after expiry would try to mint a new root of trust.
- Control plane services that use host networking, such as etcd, the kubelet and the API server, bind on a public IP. This is not a problem per se since these components all use mTLS for communication, but appropriate Hetzner Firewall rules can be added (make sure to allow UDP port 24601 for Wireguard node-to-node tunnels).
- Wigglenet is a custom network plugin with a smaller community than mainstream alternatives like Cilium or Calico. It has been used successfully for several years, though primarily in smaller-scale deployments.
- kubelet serving certificates are self-signed. This can be an issue for metrics-server. See [here for details and workarounds](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/#kubelet-serving-certs).
- Some restrictions on day-2 operations. The following are supported seamlessly, but other changes will likely require manual steps:
   - Node replacement (see notes above for control plane nodes)
   - Vertical scaling of nodes (changing the server type)
   - Horizontal scaling (changing node count).
   - Changing cluster addons settings (Wigglenet firewall settings, Hetzner API token for the Hetzner CCM and CSI). Note that `use_nftables` is effectively set at cluster creation: toggling it later redeploys Wigglenet with the new backend, but kube-proxy's mode is written at `kubeadm init` and is not updated.

In addition, some caveats apply to dual-stack clusters in general:

- `Services` are single-stack by default. Since IPv6 is the primary IP family of the clusters created with this module, this means the `ClusterIP` will be IPv6 only, leading to issues for workloads that only bind on IPv4. Pass `ipFamilyPolicy: PreferDualStack` when creating services to assign both IPv4 and IPv6 ClusterIPs. On clusters > 1.36, you can use [the following MutatingAdmissionPolicy](https://gist.github.com/tibordp/09de5c4e43b541dc555afff18fc71e9b) to change the default to `PreferDualStack`
- the apiserver Service (`kubernetes.default.svc.cluster.local`) has to be single-stack, as `--apiserver-advertise-address` does not support dual-stack yet. The default address family for the cluster can be selected with `primary_ip_family` variable (defaults to `ipv6`).


## Upgrading from v2

v3 generates the cluster PKI in Terraform and reworked the provisioning resources, so v2-created state cannot be applied directly. Existing clusters can be migrated in place, keeping the cluster CA — see the [upgrade guide](./docs/upgrading-from-v2.md).
