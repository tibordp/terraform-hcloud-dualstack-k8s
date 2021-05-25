locals {
  control_plane_endpoint_v6 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? hcloud_load_balancer.control_plane[0].ipv6 : module.master[0].ipv6_address)

  control_plane_endpoint_v4 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? hcloud_load_balancer.control_plane[0].ipv4 : module.master[0].ipv4_address)

  control_plane_endpoint = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? "[${hcloud_load_balancer.control_plane[0].ipv6}]" : "[${module.master[0].ipv6_address}]")


  # If using IP as an apiserver endpoint, add also the IPv4 SAN to the TLS certificate
  apiserver_cert_sans = concat(var.control_plane_endpoint != "" ? [
    var.control_plane_endpoint
    ] : [
    local.control_plane_endpoint_v4,
    local.control_plane_endpoint_v6
  ], var.apiserver_extra_sans)

  kubeadm_host = var.kubeadm_host != "" ? var.kubeadm_host : module.master[0].ipv4_address
}

module "master" {
  count  = var.master_count
  source = "./modules/kubernetes-node"

  name           = "${var.name}-master-${count.index}"
  hcloud_ssh_key = var.hcloud_ssh_key
  server_type    = var.master_server_type
  image          = var.image
  location       = var.location

  pool_index = 1
  node_index = count.index

  labels       = merge(var.labels, { cluster = var.name, role = "master" })
  firewall_ids = var.firewall_ids

  ssh_private_key_path = var.ssh_private_key_path
}

resource "random_id" "certificate_key" {
  byte_length = 32
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
    source      = "${path.module}/scripts/cluster-join.sh"
    destination = "/root/cluster-join.sh"
  }


  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeadm.yaml.tpl", {
      apiserverCertSans      = local.apiserver_cert_sans
      certificate_key        = random_id.certificate_key.hex
      control_plane_endpoint = local.control_plane_endpoint
      advertise_address      = module.master[0].ipv6_address
      service_cidr_ipv4      = var.service_cidr_ipv4
      service_cidr_ipv6      = var.service_cidr_ipv6
    })
    destination = "/root/cluster.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/cluster-join.sh",
      "/root/cluster-join.sh",
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
    source      = "${path.module}/scripts/cluster-join.sh"
    destination = "/root/cluster-join.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/cluster-join.sh",
      "/root/cluster-join.sh",
    ]
  }

  provisioner "remote-exec" {
    connection {
      host        = local.kubeadm_host
      type        = "ssh"
      timeout     = "5m"
      user        = "root"
      private_key = file(var.ssh_private_key_path)
    }

    inline = [
      "kubectl patch node '${module.master[count.index].node_name}' -p '${jsonencode(module.master[count.index].podcidrs_patch)}'",
    ]
  }
}