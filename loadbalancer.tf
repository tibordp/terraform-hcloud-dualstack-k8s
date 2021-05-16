locals {
  use_load_balancer = local.high_availability && (var.control_plane_lb_type != "" || var.control_plane_endpoint == "")
}

resource "hcloud_load_balancer" "control_plane" {
  count              = local.use_load_balancer ? 1 : 0
  name               = "${var.name}-control-plane"
  load_balancer_type = var.control_plane_lb_type != "" ? var.control_plane_lb_type : "lb11"
  location           = var.location
}

resource "hcloud_load_balancer_service" "control_plane" {
  count            = local.use_load_balancer ? 1 : 0
  load_balancer_id = hcloud_load_balancer.control_plane[0].id
  listen_port      = 6443
  destination_port = 6443
  protocol         = "tcp"
}

resource "hcloud_load_balancer_target" "control_plane_target" {
  count            = local.use_load_balancer ? var.master_count : 0
  type             = "server"
  load_balancer_id = hcloud_load_balancer.control_plane[0].id
  server_id        = module.master[count.index].id
}