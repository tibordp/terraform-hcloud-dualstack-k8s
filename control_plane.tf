locals {
  control_plane_endpoint_v6 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? hcloud_load_balancer.control_plane[0].ipv6 : module.control_plane[0].ipv6_address)

  control_plane_endpoint_v4 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? hcloud_load_balancer.control_plane[0].ipv4 : module.control_plane[0].ipv4_address)

  control_plane_endpoint = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? "[${hcloud_load_balancer.control_plane[0].ipv6}]" : "[${module.control_plane[0].ipv6_address}]")

  advertise_addresses = var.primary_ip_family == "ipv6" ? module.control_plane.*.ipv6_address : module.control_plane.*.ipv4_address

  # If using IP as an apiserver endpoint, add also the IPv4 SAN to the TLS certificate
  apiserver_cert_sans = concat(var.control_plane_endpoint != "" ? [
    var.control_plane_endpoint
    ] : [
    local.control_plane_endpoint_v4,
    local.control_plane_endpoint_v6
  ], var.apiserver_extra_sans)

  # Script that lays the Terraform-generated PKI roots onto a control-plane node
  # (see pki.tf). Identical for every control-plane node.
  install_pki_script = templatefile("${path.module}/templates/install-pki.sh.tpl", {
    pki_files = local.pki_files
  })
}

module "control_plane" {
  count  = var.node_count
  source = "./modules/kubernetes-node"

  name               = "${var.name}-control-plane-${count.index}"
  hcloud_ssh_key     = var.hcloud_ssh_key
  server_type        = var.server_type
  image              = var.image
  location           = var.location
  kubernetes_version = var.kubernetes_version

  labels       = merge(var.labels, { cluster = var.name, role = "control-plane" })
  firewall_ids = var.firewall_ids

  ssh_private_key_path = var.ssh_private_key_path
}

# Seed node: kubeadm init with the PKI pre-placed. Because the CAs are already on
# disk there is no certificate upload and no certificateKey -- kubeadm signs the
# leaf certs locally from them.
#
# Deliberately has no triggers_replace: it runs once for the life of the cluster.
# Without this, replacing node 0 would re-run `kubeadm init` on a blank node and
# seed a second cluster. Replacing the seed remains a manual operation.
resource "terraform_data" "cluster_bootstrap" {
  connection {
    host        = module.control_plane[0].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = local.install_pki_script
    destination = "/root/install-pki.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeadm-init.yaml.tpl", {
      advertise_address      = local.advertise_addresses[0]
      control_plane_endpoint = local.control_plane_endpoint
      apiserver_cert_sans    = local.apiserver_cert_sans
      kubernetes_version     = var.kubernetes_version
      pod_cidr_ipv4          = var.pod_cidr_ipv4
      service_cidr_ipv4      = var.service_cidr_ipv4
      service_cidr_ipv6      = var.service_cidr_ipv6
      primary_ip_family      = var.primary_ip_family
      kube_proxy_mode        = var.use_nftables ? "nftables" : "iptables"
    })
    destination = "/root/kubeadm.yaml"
  }

  # The marker is touched only after kubeadm exits 0, and makes node 0 no-op in
  # control_plane_join below once it has been seeded here. An init interrupted
  # midway leaves /etc/kubernetes half-populated, so the re-run fails kubeadm
  # preflight; recovery is a manual `kubeadm reset` on the node. Deliberately not
  # automated -- a blanket reset would wipe healthy nodes that merely lack the
  # marker.
  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "chmod +x /root/install-pki.sh && /root/install-pki.sh && rm -f /root/install-pki.sh",
      "test -f /etc/kubernetes/.terraform-provisioned || { kubeadm init --config /root/kubeadm.yaml && touch /etc/kubernetes/.terraform-provisioned; }",
    ]
  }
}

# Creates and owns the bootstrap-token Secret (not seeded at init, so `kubectl
# apply` owns it cleanly). The id -- and so the Secret name -- is stable, so
# rotating the secret half overwrites in place. All joins depend on this.
resource "terraform_data" "bootstrap_token" {
  depends_on = [terraform_data.cluster_bootstrap]

  triggers_replace = {
    token = local.bootstrap_token
  }

  connection {
    host        = module.control_plane[0].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - <<'TOKEN_EOF'\n${local.bootstrap_token_manifest}\nTOKEN_EOF",
    ]
  }
}

# Every control-plane node joins here, guarded by the .terraform-provisioned
# marker, so this covers node 0 too:
#
#   * First bootstrap: cluster_bootstrap seeds node 0 and writes the marker, so
#     join[0] no-ops; nodes 1..N join.
#   * Node 0 replaced: cluster_bootstrap is run-once and does not re-run, but the
#     fresh node 0 has no marker, so it re-joins here like any other node.
#     Discovery goes through control_plane_endpoint, so no node is special -- set
#     it to an LB/DNS that survives the replacement, and remove the dead etcd
#     member first (see the README).
#
# Joins run in parallel; etcd membership changes are best done one at a time, so
# consider -parallelism=1 when adding several control-plane nodes at once.
resource "terraform_data" "control_plane_join" {
  count = var.node_count

  depends_on = [terraform_data.bootstrap_token]

  triggers_replace = {
    instance_id = module.control_plane[count.index].id
  }

  connection {
    host        = module.control_plane[count.index].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = local.install_pki_script
    destination = "/root/install-pki.sh"
  }

  provisioner "file" {
    content     = local.discovery_kubeconfig
    destination = "/root/discovery.conf"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeadm-join.yaml.tpl", {
      control_plane     = true
      advertise_address = local.advertise_addresses[count.index]
      bootstrap_token   = local.bootstrap_token
    })
    destination = "/root/kubeadm.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "chmod +x /root/install-pki.sh && /root/install-pki.sh && rm -f /root/install-pki.sh",
      "test -f /etc/kubernetes/.terraform-provisioned || { kubeadm join --config /root/kubeadm.yaml && touch /etc/kubernetes/.terraform-provisioned; }",
    ]
  }
}
