module "kubeconfig" {
  source            = "matti/resource/shell"
  version           = "1.5.0"
  depends_on        = [null_resource.cluster_bootstrap]
  fail_on_error     = true
  sensitive_outputs = true

  trigger = null_resource.cluster_bootstrap.id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${local.kubeadm_host} 'cat /root/.kube/config'
  EOT
}

locals {
  kubeconfig                 = yamldecode(module.kubeconfig.stdout)
  certificate_authority_data = nonsensitive(base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data))
  client_certificate_data    = nonsensitive(base64decode(local.kubeconfig.users[0].user.client-certificate-data))
  client_key_data            = base64decode(local.kubeconfig.users[0].user.client-key-data)
}
