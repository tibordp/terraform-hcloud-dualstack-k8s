locals {
  control_plane_endpoint_v6 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? "[${hcloud_load_balancer.control_plane[0].ipv6}]" : "[${module.master[0].ipv6_address}]")
  control_plane_endpoint_v4 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? "[${hcloud_load_balancer.control_plane[0].ipv4}]" : "[${module.master[0].ipv4_address}]")
  kubeadm_host              = var.kubeadm_host != "" ? var.kubeadm_host : module.master[0].ipv4_address
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

resource "random_id" "certificate_key" {
  byte_length = 32
}

data "template_file" "kubeadm" {
  template = file("${path.module}/templates/kubeadm.yaml.tpl")
  vars = {
    certificate_key        = random_id.certificate_key.hex
    control_plane_endpoint = local.control_plane_endpoint_v6
    advertise_address      = module.master[0].ipv6_address
    service_cidr_ipv4      = var.service_cidr_ipv4
    service_cidr_ipv6      = var.service_cidr_ipv6
  }
}

data "template_file" "master_cni" {
  count    = var.master_count
  template = file("${path.module}/templates/cni.json.tpl")
  vars = {
    pod_subnet_v6 = module.master[count.index].pod_subnet_v6
    pod_subnet_v4 = module.master[count.index].pod_subnet_v4
  }
}

resource "null_resource" "cluster_bootstrap" {
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
    content     = data.template_file.master_cni[0].rendered
    destination = "/etc/cni/net.d/10-tibornet.conflist"
  }

  provisioner "file" {
    content     = data.template_file.kubeadm.rendered
    destination = "/root/cluster.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/cluster-init.sh",
      "/root/cluster-init.sh",
    ]
  }
}

resource "null_resource" "master_join" {
  count = var.master_count

  depends_on = [
    null_resource.cluster_bootstrap
  ]

  triggers = {
    instance_id = module.master[count.index].id
  }

  connection {
    host        = module.master[count.index].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = data.template_file.master_cni[count.index].rendered
    destination = "/etc/cni/net.d/10-tibornet.conflist"
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${local.kubeadm_host} \
        'echo $(kubeadm token create --print-join-command --ttl=60m) \
        --apiserver-advertise-address ${module.master[count.index].ipv6_address} \
        --control-plane \
        --certificate-key ${random_id.certificate_key.hex}' | \
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.master[count.index].ipv4_address} 'tee /root/join-command.sh'
    EOT
  }

  provisioner "file" {
    source      = "${path.module}/scripts/cluster-init.sh"
    destination = "/root/cluster-init.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/cluster-init.sh",
      "/root/cluster-init.sh",
    ]
  }
}