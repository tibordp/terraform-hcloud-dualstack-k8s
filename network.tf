resource "hcloud_server_network" "control_plane_server_network" {
  count = var.use_hcloud_network ? var.node_count : 0

  server_id = module.control_plane[count.index].id
  subnet_id = var.hcloud_subnet_id
}
