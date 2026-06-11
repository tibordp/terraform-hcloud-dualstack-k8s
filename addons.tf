locals {
  # hcloud secret consumed by the CCM and CSI driver, rendered as a manifest so it
  # can be applied alongside the others in a single stream.
  hcloud_secret = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "hcloud"
      namespace = "kube-system"
    }
    type = "Opaque"
    data = merge(
      { token = base64encode(var.hcloud_token) },
      var.hcloud_network_id != "" ? { network = base64encode(var.hcloud_network_id) } : {},
    )
  })

  addon_manifests = join("\n---\n", [
    local.hcloud_secret,
    templatefile("${path.module}/templates/wigglenet.yaml.tpl", {
      filter_pod_ingress_ipv6 = var.filter_pod_ingress_ipv6
      native_routing_ipv4     = var.use_hcloud_network
      firewall_backend        = var.use_nftables ? "nftables" : "iptables"
    }),
    templatefile("${path.module}/templates/hetzner_ccm.yaml.tpl", {
      use_hcloud_network = var.use_hcloud_network
      pod_cidr_ipv4      = var.pod_cidr_ipv4
    }),
    templatefile("${path.module}/templates/hetzner_csi.yaml.tpl", {}),
  ])
}

# Apply the cluster addons (CNI, CCM, CSI, hcloud secret) by piping the manifests
# straight to kubectl on the seed, over the SSH connection we already use.
#
# We deliberately do not use a Kubernetes/kubectl Terraform provider: its provider
# block would have to be configured from values not known until apply (the endpoint
# and certs), which breaks single-apply cluster creation, and the API server is
# IPv6-primary -- the machine running Terraform may not be able to reach it, while
# the seed always can.
resource "terraform_data" "install_addons" {
  depends_on = [
    terraform_data.cluster_bootstrap
  ]

  triggers_replace = {
    manifests_hash = sha256(local.addon_manifests)
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
      "kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - <<'ADDONS_EOF'\n${local.addon_manifests}\nADDONS_EOF",
    ]
  }
}
