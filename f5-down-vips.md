# F5 BIG-IP Down VIPs

Multiple legacy OSS VIPs are currently down because all their pool members are in "down" state (failing health monitors, mostly /Common/tcp).

## Down VIPs + Pools
- agentgateway-oss → pool agentgetway-oss (4 members down on 172.16.10.144 + 172.16.10.148)
- dashboard-oss → pool dashboard-oss (2 members down)
- kagent-oss → pool kagent-oss (4 members down)
- webui-oss + webui-https → pool webui-oss (2 members down)
- goose.maniak.com → pool solo.maniak.com (4 members down)

## Healthy/Up VIPs
- argo.rooster.maniak.io, vs_ui_rooster, vs_kiali, vs_mcp_gateway, vs_solo_rooster, vs_xai_gateway, vs_model_priority_gateway, vs_github_gateway, vs_vault_ui, all k8s_iceman_* services, vs_kagent_controller, etc.

The down members are on older nodes (172.16.10.144/148). Newer "rooster" and k8s_iceman services using 172.16.10.13x/Talos nodes are passing.

Note: list_pools tool incorrectly reported members_count:0 everywhere — get_pool shows the actual members + states.

Next steps: Investigate/fix the old nodes or migrate these services to the new pools.