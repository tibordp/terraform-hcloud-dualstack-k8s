module "master" {
  source = "./modules/kubernetes-node"

  name            = "${var.name}-master"
  hcloud_ssh_key  = var.hcloud_ssh_key
  server_type     = var.master_server_type
  image           = var.image
  location        = var.location
  v4_subnet_index = 0

  ssh_private_key_path = var.ssh_private_key_path
}

resource "null_resource" "master_init" {
  depends_on = [
    module.master
  ]

  connection {
    host        = module.master.ipv4_address
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
      "/root/cluster-init.sh",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl patch node '${var.name}-master' -p '${jsonencode({ "spec" = module.master.pod_cidrs })}'",
    ]
  }
}

resource "null_resource" "setup_cluster" {
  depends_on = [
    null_resource.master_init
  ]

  connection {
    host        = module.master.ipv4_address
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