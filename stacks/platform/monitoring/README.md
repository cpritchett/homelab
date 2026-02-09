# Monitoring Stack (Prometheus, Grafana, Loki)

This stack implements Task `#14` from `specs/002-label-driven-swarm-infrastructure/spec.md`.

## Services

- `prometheus`: metrics collection and retention
- `grafana`: dashboards with pre-provisioned Prometheus/Loki datasources
- `loki`: log backend
- `secrets-init`: one-shot `1password/op` runtime injection for Grafana credentials

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

## Verification

```bash
# Service status
sudo docker service ls | grep monitoring

# Secrets injector should complete without errors
sudo docker service logs monitoring_secrets-init --tail 50

# Grafana health
curl -I https://grafana.in.hypyr.space/api/health
```
