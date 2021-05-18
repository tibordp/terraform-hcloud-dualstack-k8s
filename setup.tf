resource "null_resource" "setup_cluster" {
  depends_on = [
    null_resource.cluster_bootstrap
  ]

  connection {
    host        = local.kubeadm_host
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/ip_masq_agent.yaml.tpl", {
      non_masquerade_ranges = ["10.0.0.0/8", var.service_cidr_ipv4]
    })
    destination = "/root/ip-masq-agent.yaml"
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