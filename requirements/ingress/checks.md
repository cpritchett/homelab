# Ingress Checks

Validation checklist for ingress compliance.

## Manual / CI Checks

- [ ] No port forward configs added
- [ ] No "WAN allow" firewall rules introduced
- [ ] Tunnel configs (if present) do not front management endpoints unless explicitly approved
- [ ] External services have bandwidth requirements documented
- [ ] Upload-heavy services (>10 Mbps sustained) are flagged or avoided for external exposure
- [ ] CDN/caching strategy documented for content-heavy external services
