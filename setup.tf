resource "null_resource" "setup_cluster" {
  depends_on = [
    null_resource.cluster_bootstrap
  ]

  triggers = {
    filter_pod_ingress_ipv6 = var.filter_pod_ingress_ipv6
    hcloud_token            = var.hcloud_token
  }

  connection {
    host        = local.kubeadm_host
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/wigglenet.yaml.tpl", {
      filter_pod_ingress_ipv6 = var.filter_pod_ingress_ipv6
    })
    destination = "/root/wigglenet.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/cluster-setup.sh"
    destination = "/root/cluster-setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/cluster-setup.sh",
      "HCLOUD_TOKEN='${var.hcloud_token}' /root/cluster-setup.sh",
    ]
  }
}