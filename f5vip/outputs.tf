output "vip_assignments" {
  description = "VIP → service mapping (trimmed after agentgateway/kagent removal)"
  value = {
    "argo.rooster.maniak.io (HTTPS)" = "${local.vips["argo_rooster"]}:443  → argocd-server (NodePort ${local.nodeports["argo_https"]})"
    "argo.rooster.maniak.io (HTTP)"  = "${local.vips["argo_rooster"]}:80   → argocd-server (NodePort ${local.nodeports["argo_http"]})"
    "ui.rooster.maniak.com"          = "${local.vips["ui_rooster"]}:80   → solo-enterprise-ui (NodePort ${local.nodeports["ui_rooster"]})"
    "vault.rooster.maniak.com"       = "${local.vips["vault_ui"]}:8200    → vault (NodePort ${local.nodeports["vault_ui"]})"
    "kiali.rooster.maniak.com"       = "${local.vips["kiali"]}:20001     → kiali (NodePort ${local.nodeports["kiali"]})"
  }
}
