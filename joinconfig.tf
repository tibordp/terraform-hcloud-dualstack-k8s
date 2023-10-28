locals {
  # Bootstrap token valid for 10 years
  bootstrap_token_ttl = 10 * 365 * 24
  provision_script = templatefile("${path.module}/modules/kubernetes-node/scripts/prepare-node.sh.tpl", {
    kubernetes_version = var.kubernetes_version
    kubernetes_minor_version = replace(var.kubernetes_version, "/^(\\d+\\.\\d+).*$/", "$1")
  })
}

module "join_config" {
  source            = "matti/resource/shell"
  version           = "1.5.0"
  depends_on        = [null_resource.cluster_bootstrap]
  fail_on_error     = true
  sensitive_outputs = true

  trigger = null_resource.cluster_bootstrap.id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${local.kubeadm_host} 'kubeadm token create --print-join-command --ttl=${local.bootstrap_token_ttl}h'
  EOT
}

data "cloudinit_config" "join_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = join("\n", [
      local.provision_script,
      module.join_config.stdout
    ])
  }
}
