# Monitoring Stack (Prometheus, Grafana, Loki)

This stack implements Task `#14` from `specs/002-label-driven-swarm-infrastructure/spec.md`.

## Services

- `prometheus`: metrics collection and retention
- `grafana`: dashboards with pre-provisioned Prometheus/Loki datasources
- `loki`: log backend
- `op-secrets`: one-shot `replicated-job` (ADR-0035) for Grafana credential injection via 1Password Connect

## Deployment Pattern

- Deploy via Komodo stack from `stacks/platform/monitoring/compose.yaml`.
- Configure pre-deploy hook: `scripts/validate-monitoring-setup.sh`.
- Do not run host-side long-lived deployment scripts for platform stacks.

## Required Dependencies

- Infrastructure tier running (`op-connect`, `caddy`, `komodo`)
- Docker secret: `op_connect_token`
- Docker network: `proxy_network`
- Docker network: `op-connect_op-connect`

## 1Password Item

This stack expects the following fields in item `homelab/monitoring-stack`:

- `grafana_admin_user`
- `grafana_admin_password`

If you use a different vault/item path, update `grafana.env.template`.

## Endpoints

- `https://prometheus.in.hypyr.space`
- `https://grafana.in.hypyr.space`
- `https://loki.in.hypyr.space`

## Post-Deployment Verification

```bash
# 1. Service status — all services should show 1/1 (op-secrets shows 0/1 completed)
sudo docker service ls | grep monitoring

# 2. Secrets injection completed
sudo docker service logs platform_monitoring_op-secrets --tail 10
# Expected: "Secrets injected successfully"

# 3. Prometheus health
curl -sf http://localhost:9090/-/healthy
# or via Caddy:
curl -I https://prometheus.in.hypyr.space/-/healthy

# 4. Grafana health
curl -sf https://grafana.in.hypyr.space/api/health
# Expected: {"commit":"...","database":"ok","version":"..."}

# 5. Loki readiness
curl -sf https://loki.in.hypyr.space/ready
# Expected: "ready"

# 6. Verify auto-discovery labels
sudo docker service inspect platform_monitoring_prometheus --format '{{json .Spec.Labels}}' | python3 -m json.tool
sudo docker service inspect platform_monitoring_grafana --format '{{json .Spec.Labels}}' | python3 -m json.tool
sudo docker service inspect platform_monitoring_loki --format '{{json .Spec.Labels}}' | python3 -m json.tool

# 7. Verify Grafana datasources
curl -sf -u admin:PASSWORD https://grafana.in.hypyr.space/api/datasources | python3 -m json.tool
# Expected: Prometheus and Loki datasources listed
```

## Known Gaps

- **No Grafana dashboard provisioning**: Dashboards must be created manually or added to `grafana/provisioning/dashboards/`
- **No log shipping**: Loki is ready to receive logs but no log collector (Promtail/Alloy) is deployed yet
- **No alerting rules**: Prometheus alerting rules and Alertmanager are not configured
- **No Prometheus service discovery**: Scrape targets are static in `prometheus.yml`; consider adding Docker SD for automatic target discovery
- **No persistent Grafana state**: Dashboard changes are lost on redeployment unless exported and provisioned
