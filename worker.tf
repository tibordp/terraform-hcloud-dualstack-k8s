module "worker" {
  count  = var.worker_count
  source = "./modules/kubernetes-node"

  name           = "${var.name}-worker-${count.index}"
  hcloud_ssh_key = var.hcloud_ssh_key
  server_type    = var.worker_server_type
  image          = var.image
  location       = var.location

  # Subnets for workers start at 32, to allow for the master
  # count to be increased. 32 master nodes ought to be enough for
  # everyone ;)
  node_index = 32 + count.index

  labels       = merge(var.labels, { cluster = var.name, role = "worker" })
  firewall_ids = var.firewall_ids

  ssh_private_key_path = var.ssh_private_key_path
}

resource "null_resource" "worker_join" {
  count = var.worker_count

  depends_on = [
    null_resource.master_init
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

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.master[0].ipv4_address} 'kubeadm token create --print-join-command --ttl=60m' | \
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.worker[count.index].ipv4_address}
    EOT
  }

  provisioner "remote-exec" {
    connection {
      host        = module.master[0].ipv4_address
      type        = "ssh"
      timeout     = "5m"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
    }

    inline = [
      <<EOT
      kubectl patch node '${var.name}-worker-${count.index}' \
        -p '${jsonencode({ "spec" = module.worker[count.index].pod_cidrs })}'
      EOT
    ]
  }
}