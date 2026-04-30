locals {
  # VIP assignments from 172.16.20.120-130 range (trimmed after agentgateway/kagent removal)
  vips = {
    argo_rooster = "172.16.20.121" # argo.rooster.maniak.io (ArgoCD)
    ui_rooster   = "172.16.20.130" # ui.rooster.maniak.com (Solo Enterprise UI)
    vault_ui     = "172.16.20.126" # vault.rooster.maniak.com (Vault UI)
    kiali        = "172.16.20.127" # kiali.rooster.maniak.com (Kiali mesh UI)
  }

  # NodePort mappings from live cluster
  nodeports = {
    argo_https = 31988 # argocd-server 443:31988
    argo_http  = 32178 # argocd-server 80:32178
    ui_rooster = 31211 # solo-enterprise-ui 80:31211
    vault_ui   = 30820 # vault 8200:30820
    kiali      = 31094 # kiali 20001:31094
  }

  # Build pool member lists: each node on the relevant NodePort
  pool_members = { for name, port in local.nodeports :
    name => [for ip in var.backend_nodes : "${ip}:${port}"]
  }
}

resource "bigip_ltm_monitor" "tcp" {
  name     = "/${var.partition}/rooster_tcp_monitor"
  parent   = "/Common/tcp"
  interval = 10
  timeout  = 31
}

resource "bigip_ltm_pool" "argo_https" {
  name                = "/${var.partition}/pool_argo_rooster_https"
  load_balancing_mode = "round-robin"
  monitors            = [bigip_ltm_monitor.tcp.name]
}

resource "bigip_ltm_pool_attachment" "argo_https" {
  for_each = toset(local.pool_members["argo_https"])
  pool     = bigip_ltm_pool.argo_https.name
  node     = "/${var.partition}/${each.value}"
}

resource "bigip_ltm_pool" "argo_http" {
  name                = "/${var.partition}/pool_argo_rooster_http"
  load_balancing_mode = "round-robin"
  monitors            = [bigip_ltm_monitor.tcp.name]
}

resource "bigip_ltm_pool_attachment" "argo_http" {
  for_each = toset(local.pool_members["argo_http"])
  pool     = bigip_ltm_pool.argo_http.name
  node     = "/${var.partition}/${each.value}"
}

resource "bigip_ltm_pool" "ui_rooster" {
  name                = "/${var.partition}/pool_ui_rooster"
  load_balancing_mode = "round-robin"
  monitors            = [bigip_ltm_monitor.tcp.name]
}

resource "bigip_ltm_pool_attachment" "ui_rooster" {
  for_each = toset(local.pool_members["ui_rooster"])
  pool     = bigip_ltm_pool.ui_rooster.name
  node     = "/${var.partition}/${each.value}"
}

resource "bigip_ltm_pool" "vault_ui" {
  name                = "/${var.partition}/pool_vault_ui"
  load_balancing_mode = "round-robin"
  monitors            = [bigip_ltm_monitor.tcp.name]
}

resource "bigip_ltm_pool_attachment" "vault_ui" {
  for_each = toset(local.pool_members["vault_ui"])
  pool     = bigip_ltm_pool.vault_ui.name
  node     = "/${var.partition}/${each.value}"
}

resource "bigip_ltm_pool" "kiali" {
  name                = "/${var.partition}/pool_kiali"
  load_balancing_mode = "round-robin"
  monitors            = [bigip_ltm_monitor.tcp.name]
}

resource "bigip_ltm_pool_attachment" "kiali" {
  for_each = toset(local.pool_members["kiali"])
  pool     = bigip_ltm_pool.kiali.name
  node     = "/${var.partition}/${each.value}"
}

# --- argo.rooster.maniak.io (HTTPS - L4 passthrough) ---
resource "bigip_ltm_virtual_server" "argo_https" {
  name                       = "/${var.partition}/vs_argo_rooster_https"
  destination                = local.vips["argo_rooster"]
  port                       = 443
  pool                       = bigip_ltm_pool.argo_https.name
  ip_protocol                = "tcp"
  source_address_translation = "automap"
  profiles                   = ["/Common/fastL4"]
}

# --- argo.rooster.maniak.io (HTTP redirect target / optional) ---
resource "bigip_ltm_virtual_server" "argo_http" {
  name                       = "/${var.partition}/vs_argo_rooster_http"
  destination                = local.vips["argo_rooster"]
  port                       = 80
  pool                       = bigip_ltm_pool.argo_http.name
  ip_protocol                = "tcp"
  source_address_translation = "automap"
  profiles                   = ["/Common/fastL4"]
}

# --- ui.rooster.maniak.com (Solo Enterprise UI - L4 TCP) ---
resource "bigip_ltm_virtual_server" "ui_rooster" {
  name                       = "/${var.partition}/vs_ui_rooster"
  destination                = local.vips["ui_rooster"]
  port                       = 80
  pool                       = bigip_ltm_pool.ui_rooster.name
  ip_protocol                = "tcp"
  source_address_translation = "automap"
  profiles                   = ["/Common/fastL4"]
}

# --- vault.rooster.maniak.com (Vault UI - L4 TCP) ---
resource "bigip_ltm_virtual_server" "vault_ui" {
  name                       = "/${var.partition}/vs_vault_ui"
  destination                = local.vips["vault_ui"]
  port                       = 8200
  pool                       = bigip_ltm_pool.vault_ui.name
  ip_protocol                = "tcp"
  source_address_translation = "automap"
  profiles                   = ["/Common/fastL4"]
}

# --- kiali.rooster.maniak.com (Kiali Mesh UI - L4 TCP) ---
resource "bigip_ltm_virtual_server" "kiali" {
  name                       = "/${var.partition}/vs_kiali"
  destination                = local.vips["kiali"]
  port                       = 20001
  pool                       = bigip_ltm_pool.kiali.name
  ip_protocol                = "tcp"
  source_address_translation = "automap"
  profiles                   = ["/Common/fastL4"]
}
