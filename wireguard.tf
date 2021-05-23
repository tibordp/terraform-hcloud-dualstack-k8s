locals {
  wireguard_peers = [for i, server in local.all_nodes : {
    public_key = server.wireguard_public_key
    allowed_ips = [
      server.pod_subnet_v4,
      server.ipv6_network,
    ]
    routes = [
      server.pod_subnet_v4,
      server.pod_subnet_v6,
    ]
    endpoint = server.ipv6_address
  }]
}

resource "null_resource" "wireguard" {
  count = len(local.all_nodes)

  triggers = {
    "id" : local.all_nodes[count.index].id
    "peers" : jsonencode(local.wireguard_peers)
  }

  connection {
    host        = local.all_nodes[count.index].ipv4_address
    type        = "ssh"
    timeout     = "5m"
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/wireguard.yaml.tpl", {
      addresses = [
        "${local.all_nodes[count.index].private_ipv4_address}/32"
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