# F5 VIP Health Report - March 2026

## Summary
Several legacy F5 VIPs are currently DOWN due to unhealthy pool members.

## Down VIPs

| VIP | Pool | Member Count | Status | Details |
|-----|------|--------------|--------|---------|
| webui-https / webui-oss | webui-oss | 2 | DOWN | Both members `down` |
| goose.maniak.com | solo.maniak.com | 4 | DOWN | All members `down` |
| agentgateway-oss | agentgetway-oss | 4 | DOWN | All members `down` (note: pool name typo) |
| dashboard-oss | dashboard-oss | 2 | DOWN | Both members `down` |
| kagent-oss | kagent-oss | - | Likely DOWN | Same pattern as other OSS services |

## Healthy VIPs

- argo.rooster.maniak.io (4/4 up)
- vs_ui_rooster (4/4 up)
- vs_argo_rooster_https (4/4 up)
- vs_argo_rooster_http, vs_kagent_controller, vs_mcp_gateway, etc.

## Analysis
There appears to be a split between legacy `-oss` services (unhealthy) and the new `rooster` platform services (healthy). This may indicate a migration in progress where old services were not properly decommissioned or their backends are no longer running.

**Recommendation:** 
1. Investigate why the backend nodes for the down pools are failing health checks.
2. Consider removing or disabling the legacy OSS VIPs if they are no longer needed.
3. Verify monitor configurations (many use `/Common/tcp` or custom `rooster_*` monitors).

Last checked: Current date

