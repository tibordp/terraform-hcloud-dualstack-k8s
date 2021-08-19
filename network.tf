resource "hcloud_server_network" "master_server_network" {
  count = var.use_hcloud_network ? var.master_count : 0

  server_id = module.master[count.index].id
  subnet_id = var.hcloud_subnet_id
}

resource "hcloud_server_network" "worker_server_network" {
  count = var.use_hcloud_network ? var.worker_count : 0

  server_id = module.worker[count.index].id
  subnet_id = var.hcloud_subnet_id
}
