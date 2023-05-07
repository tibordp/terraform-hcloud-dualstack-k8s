locals {
  control_plane_endpoint_v6 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? hcloud_load_balancer.control_plane[0].ipv6 : module.control_plane[0].ipv6_address)

  control_plane_endpoint_v4 = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? hcloud_load_balancer.control_plane[0].ipv4 : module.control_plane[0].ipv4_address)

  control_plane_endpoint = var.control_plane_endpoint != "" ? var.control_plane_endpoint : (local.use_load_balancer ? "[${hcloud_load_balancer.control_plane[0].ipv6}]" : "[${module.control_plane[0].ipv6_address}]")

  adverise_addresses = var.primary_ip_family == "ipv6" ? module.control_plane.*.ipv6_address : module.control_plane.*.ipv4_address

  # If using IP as an apiserver endpoint, add also the IPv4 SAN to the TLS certificate
  apiserver_cert_sans = concat(var.control_plane_endpoint != "" ? [
    var.control_plane_endpoint
    ] : [
    local.control_plane_endpoint_v4,
    local.control_plane_endpoint_v6
  ], var.apiserver_extra_sans)

  kubeadm_host = var.kubeadm_host != "" ? var.kubeadm_host : module.control_plane[0].ipv4_address
}

module "control_plane" {
  count  = var.control_plane_count
  source = "./modules/kubernetes-node"

  name               = "${var.name}-control-plane-${count.index}"
  hcloud_ssh_key     = var.hcloud_ssh_key
  server_type        = var.control_plane_server_type
  image              = var.image
  location           = var.location
  kubernetes_version = var.kubernetes_version

  labels       = merge(var.labels, { cluster = var.name, role = "control-plane" })
  firewall_ids = var.firewall_ids

  ssh_private_key_path = var.ssh_private_key_path
}

resource "random_id" "certificate_key" {
  byte_length = 32
}

resource "null_resource" "cluster_bootstrap" {
  connection {
    host        = module.control_plane[0].ipv4_address
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
      apiserver_cert_sans    = local.apiserver_cert_sans
      certificate_key        = random_id.certificate_key.hex
      control_plane_endpoint = local.control_plane_endpoint
      advertise_address      = local.adverise_addresses[0]
      pod_cidr_ipv4          = var.pod_cidr_ipv4
      service_cidr_ipv4      = var.service_cidr_ipv4
      service_cidr_ipv6      = var.service_cidr_ipv6
      primary_ip_family      = var.primary_ip_family
      kubernetes_version     = var.kubernetes_version
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

resource "null_resource" "control_plane_join" {
  count = var.control_plane_count

  depends_on = [
    null_resource.cluster_bootstrap
  ]

  triggers = {
    instance_id = module.control_plane[count.index].id
  }

  connection {
    host        = module.control_plane[count.index].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          root@${local.kubeadm_host} 'kubeadm init phase upload-certs \
            --upload-certs \
            --certificate-key ${random_id.certificate_key.hex}'
    EOT
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${local.kubeadm_host} \
        'echo $(kubeadm token create --print-join-command --ttl=60m) \
        --apiserver-advertise-address ${local.adverise_addresses[count.index]} \
        --control-plane \
        --certificate-key ${random_id.certificate_key.hex}' | \
      ssh -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        root@${module.control_plane[count.index].ipv4_address} 'tee /root/join-command.sh >/dev/null'
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
}
