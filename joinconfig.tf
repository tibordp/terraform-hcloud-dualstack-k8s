locals {
  # Bootstrap token valid for 10 years
  bootstrap_token_ttl = 10 * 365 * 24
}

module "join_config" {
  source     = "matti/resource/shell"
  depends_on = [null_resource.cluster_bootstrap]

  trigger = null_resource.cluster_bootstrap.id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${local.kubeadm_host} 'kubeadm token create --print-join-command --ttl=${local.bootstrap_token_ttl}h'
  EOT
}

data "template_cloudinit_config" "join_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = join("\n", [
      file("${path.module}/modules/kubernetes-node/scripts/prepare-node.sh"),
      module.join_config.stdout
    ])
  }
}
