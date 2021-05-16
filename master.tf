locals {
  high_availability      = var.control_plane_endpoint != "" || var.master_count > 1 || var.control_plane_lb_type != ""
  control_plane_endpoint = local.high_availability ? (var.control_plane_endpoint != "" ? var.control_plane_endpoint : hcloud_load_balancer.control_plane[0].ipv4) : ""
}

module "master" {
  count  = var.master_count
  source = "./modules/kubernetes-node"

  name           = "${var.name}-master-${count.index}"
  hcloud_ssh_key = var.hcloud_ssh_key
  server_type    = var.master_server_type
  image          = var.image
  location       = var.location
  node_index     = count.index

  labels       = merge(var.labels, { cluster = var.name, role = "master" })
  firewall_ids = var.firewall_ids

  ssh_private_key_path = var.ssh_private_key_path
}


module "certificate_key" {
  count      = local.high_availability ? 1 : 0
  source     = "matti/resource/shell"
  depends_on = [module.master]

  trigger = module.master[0].id

  command = <<EOT
    ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      root@${module.master[0].ipv4_address} 'kubeadm certs certificate-key'
  EOT
}

data "template_file" "kubeadm" {
  template = file("${path.module}/templates/kubeadm.yaml.tpl")
  vars = {
    ha_control_plane       = local.high_availability
    certificate_key        = local.high_availability ? module.certificate_key[0].stdout : ""
    control_plane_endpoint = local.high_availability ? local.control_plane_endpoint : ""
    advertise_address      = module.master[0].ipv4_address
    service_cidr_ipv4      = var.service_cidr_ipv4
    service_cidr_ipv6      = var.service_cidr_ipv6
  }
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

  provisioner "file" {
    content     = data.template_file.kubeadm.rendered
    destination = "/root/cluster.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/cluster-init.sh",
      "HA_CONTROL_PLANE=${local.high_availability ? 1 : 0} /root/cluster-init.sh",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      <<EOT
      kubectl patch node '${var.name}-master-0' \
        -p '${jsonencode({ "spec" = module.master[0].pod_cidrs })}'
      EOT
    ]
  }
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
  count = local.high_availability ? var.master_count - 1 : 0

  depends_on = [
    null_resource.master_init
  ]

  triggers = {
    instance_id  = module.master[count.index + 1].id
    ipv4_address = module.master[count.index + 1].ipv4_address
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.master[0].ipv4_address} \
        'echo $(kubeadm token create --print-join-command --ttl=60m) \
        --apiserver-advertise-address ${module.master[count.index + 1].ipv4_address} \
        --control-plane \
        --certificate-key ${module.certificate_key[0].stdout} \
        --skip-phases control-plane-join' | \
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
      <<EOT
      kubectl patch node '${var.name}-master-${count.index + 1}' \
        -p '${jsonencode({ "spec" = module.master[count.index + 1].pod_cidrs })}'
      EOT
    ]
  }

  # We need CNI to be operational on the node before we can complete the join
  provisioner "remote-exec" {
    connection {
      host        = self.triggers.ipv4_address
      type        = "ssh"
      timeout     = "5m"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
    }

    inline = [
      <<EOT
      kubeadm join phase control-plane-join all \
        --control-plane \
        --apiserver-advertise-address ${module.master[count.index + 1].ipv4_address}
      EOT
    ]
  }

  # It is important to leave the etcd quorum before shutting down the control plane node,
  # as it will not be done automatically. This deprovisioner can only use the default ssh key due to
  # https://github.com/hashicorp/terraform/issues/23679
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${self.triggers.ipv4_address} 'kubeadm reset --force --skip-phases cleanup-node'
    EOT
  }
}