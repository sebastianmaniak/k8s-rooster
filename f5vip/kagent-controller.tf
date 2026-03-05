# kagent-controller (external VIP -> NodePort)

locals {
  # VIP for kagent-controller (suggested)
  kagent_controller_vip = "172.16.20.131"

  # NodePort for kagent-controller (created by kagent-extras app)
  kagent_controller_nodeport = 32083

  kagent_controller_nodes = [
    "172.16.10.130",
    "172.16.10.132",
    "172.16.10.133",
    "172.16.10.136",
  ]

  kagent_controller_pool_members = [
    for n in local.kagent_controller_nodes : "${n}:${local.kagent_controller_nodeport}"
  ]
}

resource "bigip_ltm_pool" "kagent_controller" {
  name                = "/${var.partition}/pool_kagent_controller"
  load_balancing_mode = "round-robin"
  monitors            = [bigip_ltm_monitor.tcp.name]
}

resource "bigip_ltm_pool_attachment" "kagent_controller" {
  for_each = toset(local.kagent_controller_pool_members)
  pool     = bigip_ltm_pool.kagent_controller.name
  node     = "/${var.partition}/${each.value}"
}

resource "bigip_ltm_virtual_server" "kagent_controller" {
  name                       = "/${var.partition}/vs_kagent_controller"
  destination                = local.kagent_controller_vip
  port                       = 8083
  pool                       = bigip_ltm_pool.kagent_controller.name
  ip_protocol                = "tcp"
  source_address_translation = "automap"
  profiles                   = ["/Common/fastL4"]
}
