module "kubeconfig" {
  source     = "matti/resource/shell"
  depends_on = [null_resource.master_init]

  trigger = module.master[0].id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${module.master[0].ipv4_address} 'cat /root/.kube/config'
  EOT
}

module "certificate_authority_data" {
  source     = "matti/resource/shell"
  depends_on = [null_resource.master_init]

  trigger = module.master[0].id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path}  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${module.master[0].ipv4_address} 'kubectl config --kubeconfig /root/.kube/config view --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}''
  EOT
}

module "client_certificate_data" {
  source     = "matti/resource/shell"
  depends_on = [null_resource.master_init]

  trigger = module.master[0].id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path}  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${module.master[0].ipv4_address} 'kubectl config --kubeconfig /root/.kube/config view --flatten -o jsonpath='{.users[0].user.client-certificate-data}''
  EOT
}

module "client_key_data" {
  source     = "matti/resource/shell"
  depends_on = [null_resource.master_init]

  trigger = module.master[0].id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path}  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${module.master[0].ipv4_address} 'kubectl config --kubeconfig /root/.kube/config view --flatten -o jsonpath='{.users[0].user.client-key-data}''
  EOT
}