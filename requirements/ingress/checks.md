# Ingress Checks

Validation checklist for ingress compliance.

## Manual / CI Checks

- [ ] No port forward configs added
- [ ] No "WAN allow" firewall rules introduced
- [ ] Tunnel configs (if present) do not front management endpoints unless explicitly approved
