module "worker" {
  count  = var.worker_count
  source = "./modules/kubernetes-node"

  name           = "${var.name}-worker-${count.index}"
  hcloud_ssh_key = var.hcloud_ssh_key
  server_type    = var.worker_server_type
  image          = var.image
  location       = var.location

  pool_index = 2
  node_index = count.index

  labels       = merge(var.labels, { cluster = var.name, role = "worker" })
  firewall_ids = var.firewall_ids

  ssh_private_key_path = var.ssh_private_key_path
}

data "template_file" "worker_cni" {
  count    = var.worker_count
  template = file("${path.module}/templates/cni.json.tpl")
  vars = {
    pod_subnet_v6 = module.worker[count.index].pod_subnet_v6
    pod_subnet_v4 = module.worker[count.index].pod_subnet_v4
  }
}

resource "null_resource" "worker_join" {
  count = var.worker_count

  depends_on = [
    null_resource.cluster_bootstrap
  ]

  triggers = {
    instance_id = module.worker[count.index].id
  }

  connection {
    host        = module.worker[count.index].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = data.template_file.worker_cni[count.index].rendered
    destination = "/etc/cni/net.d/10-tibornet.conflist"
  }


  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${local.kubeadm_host} 'kubeadm token create --print-join-command --ttl=60m' | \
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.worker[count.index].ipv4_address}
    EOT
  }
}