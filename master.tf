locals {
  ha_control_plane = var.master_count > 1
  ha_params        = local.ha_control_plane ? "APISERVER_ENDPOINT='${hcloud_load_balancer.control_plane[0].ipv4}' CERTIFICATE_KEY='${module.certificate_key[0].stdout}'" : ""
}

module "master" {
  count  = var.master_count
  source = "./modules/kubernetes-node"

  name            = "${var.name}-master-${count.index}"
  hcloud_ssh_key  = var.hcloud_ssh_key
  server_type     = var.master_server_type
  image           = var.image
  location        = var.location
  v4_subnet_index = count.index

  ssh_private_key_path = var.ssh_private_key_path
}


module "certificate_key" {
  count      = local.ha_control_plane ? 1 : 0
  source     = "matti/resource/shell"
  depends_on = [module.master]

  trigger = module.master[0].id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${module.master[0].ipv4_address} 'kubeadm certs certificate-key'
  EOT
}

resource "null_resource" "master_init" {
  depends_on = [
    module.certificate_key
  ]

  connection {
    host        = module.master[0].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    source      = "${path.module}/scripts/cluster-init.sh"
    destination = "/root/cluster-init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/cluster-init.sh",
      "${local.ha_params} /root/cluster-init.sh",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl patch node '${var.name}-master-0' -p '${jsonencode({ "spec" = module.master[0].pod_cidrs })}'",
    ]
  }
}

resource "hcloud_load_balancer" "control_plane" {
  count              = local.ha_control_plane ? 1 : 0
  name               = "${var.name}-control-plane"
  load_balancer_type = "lb11"
  location           = var.location
}

resource "hcloud_load_balancer_service" "control_plane" {
  count            = local.ha_control_plane ? 1 : 0
  load_balancer_id = hcloud_load_balancer.control_plane[0].id
  listen_port      = 6443
  destination_port = 6443
  protocol         = "tcp"
}

resource "hcloud_load_balancer_target" "control_plane_target" {
  count            = local.ha_control_plane ? var.master_count : 0
  type             = "server"
  load_balancer_id = hcloud_load_balancer.control_plane[0].id
  server_id        = module.master[count.index].id
}

resource "null_resource" "setup_cluster" {
  depends_on = [
    null_resource.master_init
  ]

  connection {
    host        = module.master[0].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
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


resource "null_resource" "master_join" {
  count = local.ha_control_plane ? var.master_count - 1 : 0

  depends_on = [
    null_resource.master_init
  ]

  connection {
    host        = module.master[count.index + 1].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.master[0].ipv4_address} \
        'echo $(kubeadm token create --print-join-command --ttl=60m) --control-plane --certificate-key ${module.certificate_key[0].stdout}' | \
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.master[count.index + 1].ipv4_address}
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
      "kubectl patch node '${var.name}-master-${count.index + 1}' -p '${jsonencode({ "spec" = module.master[count.index + 1].pod_cidrs })}'",
    ]
  }
}