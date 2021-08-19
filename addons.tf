resource "null_resource" "install_addons" {
  depends_on = [
    null_resource.cluster_bootstrap
  ]

  triggers = {
    wigglenet_manifest = templatefile("${path.module}/templates/wigglenet.yaml.tpl", {
      filter_pod_ingress_ipv6 = var.filter_pod_ingress_ipv6
      native_routing_ipv4     = var.use_hcloud_network
    })
    ccm_manifest = templatefile("${path.module}/templates/hetzner_ccm.yaml.tpl", {
      use_hcloud_network = var.use_hcloud_network
      pod_cidr_ipv4      = var.pod_cidr_ipv4
    })
    csi_manifest = templatefile("${path.module}/templates/hetzner_csi.yaml.tpl", {})
    hcloud_token = var.hcloud_token
  }

  connection {
    host        = local.kubeadm_host
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = self.triggers.wigglenet_manifest
    destination = "/root/wigglenet.yaml"
  }

  provisioner "file" {
    content     = self.triggers.ccm_manifest
    destination = "/root/hetzner_ccm.yaml"
  }

  provisioner "file" {
    content     = self.triggers.csi_manifest
    destination = "/root/hetzner_csi.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-addons.sh"
    destination = "/root/install-addons.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/install-addons.sh",
      "HCLOUD_TOKEN='${var.hcloud_token}' HCLOUD_NETWORK='${var.hcloud_network_id}' /root/install-addons.sh",
    ]
  }
}
