locals {
  wireguard_peers = [for i, server in concat(module.master, module.worker) : {
    public_key = server.wireguard_public_key
    allowed_ips = [
      "${server.private_ipv4_address}/32",
      server.pod_subnet_v4,
      server.ipv6_network,
    ]
    routes = [
      "${server.private_ipv4_address}/32",
      server.pod_subnet_v4,
      server.pod_subnet_v6,
    ]
    endpoint = server.ipv6_address
  }]
}

resource "null_resource" "master_wireguard" {
  count = var.master_count

  triggers = {
    "id" : module.master[count.index].id
    "peers" : jsonencode(local.wireguard_peers)
  }

  connection {
    host        = module.master[count.index].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/wireguard.yaml.tpl", {
      addresses = [
        "${module.master[count.index].private_ipv4_address}/32"
      ]
      peers = concat(
        slice(local.wireguard_peers, 0, count.index),
        slice(local.wireguard_peers, count.index + 1, length(local.wireguard_peers))
      )
    })
    destination = "/etc/netplan/60-wireguard.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      # Passing key by filename in netplan is only supported with systemd-network backend
      "sed -i \"s#__PRIVATE_KEY__#$(cat /etc/wg_priv.key)#g\" /etc/netplan/60-wireguard.yaml",
      "netplan apply",
    ]
  }
}

resource "null_resource" "worker_wireguard" {
  count = var.worker_count

  triggers = {
    "id" : module.worker[count.index].id
    "peers" : jsonencode(local.wireguard_peers)
  }

  connection {
    host        = module.worker[count.index].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/wireguard.yaml.tpl", {
      addresses = [
        "${module.worker[count.index].private_ipv4_address}/32"
      ]
      peers = concat(
        slice(local.wireguard_peers, 0, var.master_count + count.index),
        slice(local.wireguard_peers, var.master_count + count.index + 1, length(local.wireguard_peers))
      )

    })
    destination = "/etc/netplan/60-wireguard.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      # Passing key by filename in netplan is only supported with systemd-network backend
      "sed -i \"s#__PRIVATE_KEY__#$(cat /etc/wg_priv.key)#g\" /etc/netplan/60-wireguard.yaml",
      "netplan apply"
    ]
  }
}