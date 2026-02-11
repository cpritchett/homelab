# Research: Label-Driven Docker Swarm Infrastructure

**Date**: 2026-02-10
**Spec**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)

## Overview

This research addresses the remaining tasks and technology decisions for the label-driven Docker Swarm infrastructure feature. The core pattern (Caddy + Homepage + AutoKuma label-driven discovery) is already implemented. Research focuses on three remaining workstreams: Authentik SSO deployment, monitoring stack completion, and Cloudflare Tunnel for external webhooks.

---

## R1: Authentik SSO Deployment (Task #12)

### Decision: Distributed Multi-Service Stack with One-Shot Secret Hydration

**Rationale**: Authentik requires four services (server, worker, PostgreSQL, Redis) with complex secret management. The existing pattern of `replicated-job` mode for 1Password `op inject` (ADR-0035) applies directly. Caddy forward authentication labels enable SSO for downstream services.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Single-container Authentik | No worker separation; background tasks block HTTP requests |
| Embedded SQLite | No backup tooling; no scalability path; Authentik recommends PostgreSQL |
| API key auth for monitoring | AutoKuma uses WebSocket (not REST); only username/password auth works |
| Manual Caddyfile for forward_auth | Violates ADR-0034 label-driven requirement |

### Key Findings

**Secret Management**:
- One-shot `replicated-job` hydrates secrets via `op inject` into `/mnt/apps01/appdata/authentik/secrets/`
- Template file maps `op://homelab/authentik-stack/*` fields to environment variables
- Main services source env file at startup: `set -a && . /secrets/authentik.env && set +a`
- 1Password item `authentik-stack` in `homelab` vault with fields: `secret_key`, `bootstrap_email`, `bootstrap_password`, `postgres_password`

**Caddy Forward Authentication Pattern**:
- Protected services use `caddy.forward_auth` labels pointing to Authentik server
- Headers copied: `X-Authentik-Username`, `X-Authentik-Groups`, `X-Authentik-Email`, `X-Authentik-Name`, `X-Authentik-Uid`
- Authentik server must be on `proxy_network` for Caddy to reach it
- Forward auth label pattern documented in `stacks/docs/CADDY_FORWARD_AUTH_LABELS.md`

**Network Architecture**:
- `authentik` overlay: Internal service-to-service (PostgreSQL, Redis, worker)
- `proxy_network` external: Caddy ingress to Authentik server
- `op-connect_op-connect` external: 1Password Connect for secret hydration

**Database**:
- External PostgreSQL container (not embedded) for independent backup/recovery
- PostgreSQL on `/mnt/data01/` (archive tier); secrets on `/mnt/apps01/` (fast tier)
- Redis with `--save 60 1` for session persistence across restarts

**Resource Allocation**:
- Server/Worker: 2 CPU limit, 1 CPU reserved, 2048M limit, 1024M reserved
- PostgreSQL: 2 CPU limit, 1 CPU reserved, 2048M limit, 1024M reserved
- Redis: 1 CPU limit, 0.5 CPU reserved, 512M limit, 256M reserved
- Secrets init job: 0.5 CPU, 256M (minimal, runs once)

---

## R2: Monitoring Stack Completion (Task #14)

### Decision: Prometheus + Grafana + Loki with Label-Driven Discovery

**Rationale**: The monitoring stack compose and configuration files are complete. Implementation follows the same one-shot secret hydration pattern. Remaining work is deployment via Komodo and post-deployment verification.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Victoria Metrics | Less community support; Prometheus is more widely documented |
| InfluxDB + Telegraf | Different paradigm; Prometheus better for service monitoring |
| Datadog/cloud SaaS | Cost; data sovereignty; dependency on external service |
| Promtail for log collection | Additional service; Docker logging driver is simpler for Swarm |

### Key Findings

**Current State**:
- Compose file: Complete (`stacks/platform/monitoring/compose.yaml`)
- Prometheus config: Basic self-scraping (prometheus, grafana, loki targets)
- Grafana provisioning: Datasources configured (Prometheus + Loki, proxy mode)
- Loki config: Filesystem storage, auth disabled, TSDB schema
- Validation script: Complete (`scripts/validate-monitoring-setup.sh`)
- Status: **Implementation complete, pending deployment**

**Gaps Identified**:

1. **No Grafana dashboard provisioning**: Only datasources are provisioned. No pre-built dashboards for Docker Swarm, node metrics, or service health. Dashboards can be added post-deployment via Grafana UI or `grafana/provisioning/dashboards/` directory.

2. **No alerting rules**: Prometheus has no `rule_files` configured. Alerting can be added incrementally after baseline monitoring is established.

3. **No log collection pipeline**: Loki is deployed but no log shipping mechanism exists. Options:
   - Docker logging driver (`loki` driver) — requires daemon-level config on TrueNAS
   - Promtail sidecar — additional service per stack
   - Alloy (Grafana Agent) — unified collection agent
   - **Recommendation**: Start with Loki API push from applications; add Docker logging driver later

4. **No Prometheus service discovery for Swarm**: Current config uses static scrape targets. Docker Swarm service discovery (`dockerswarm_sd_configs`) can auto-discover services exposing metrics ports.

**Label Integration**:
- All three services (Prometheus, Grafana, Loki) have full label sets:
  - Homepage: `homepage.group: "Monitoring"` with widget integration
  - Caddy: Internal TLS (`*.in.hypyr.space`) with Cloudflare DNS-01
  - AutoKuma: Health endpoints (`/-/healthy`, `/ready`, `/api/health`)
- Grafana Homepage widget uses `{{HOMEPAGE_VAR_GRAFANA_USER}}` / `{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}` for authenticated widget access

**Secret Management**:
- `op-secrets` replicated-job hydrates `grafana.env.template` → `/mnt/apps01/appdata/monitoring/secrets/grafana.env`
- 1Password item: `monitoring-stack` in `homelab` vault with `grafana_admin_user`, `grafana_admin_password`
- Grafana sources env file at startup via entrypoint wrapper

**Directory Permissions** (from validation script):
- `/mnt/apps01/appdata/monitoring/` — root:root, 755
- `/mnt/apps01/appdata/monitoring/secrets/` — 472:472 (Grafana UID), 750
- `/mnt/data01/appdata/monitoring/prometheus/` — 65534:65534 (nobody), 755
- `/mnt/data01/appdata/monitoring/grafana/` — 472:472 (Grafana UID), 755
- `/mnt/data01/appdata/monitoring/loki/` — 10001:10001 (Loki UID), 755

---

## R3: Cloudflare Tunnel for External Webhooks (Task #15)

### Decision: Cloudflare Tunnel as Docker Swarm Service with Caddy Integration

**Rationale**: ADR-0002 mandates tunnel-only ingress. Cloudflare Tunnel maintains a persistent outbound connection to Cloudflare edge, routing external traffic to Caddy without WAN port exposure. This completes the external access story for services like Komodo GitHub webhooks.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Port forwarding | Violates ADR-0002 (tunnel-only ingress); WAN exposure prohibited |
| Caddy with direct WAN exposure | Same violation; requires open ports on residential ISP |
| ngrok / Tailscale Funnel | Additional vendor dependency; Cloudflare already in use for DNS |
| Per-service tunnels | Violates DRY; credential management overhead; centralized tunnel is better |

### Key Findings

**Architecture**:
```
GitHub webhook → Cloudflare edge → Cloudflare Tunnel → cloudflared (Swarm) → Caddy → Komodo
```

- Tunnel maintains persistent outbound connection (no inbound ports)
- All public FQDNs (`*.hypyr.space`) resolve to Cloudflare, which routes through tunnel
- Caddy handles HTTPS termination and routing via existing label-driven pattern
- Single tunnel service routes all external traffic

**Secret Management**:
- Tunnel credentials stored in 1Password item `cloudflare-tunnel` in `homelab` vault
- One-shot hydration job (ADR-0035) injects credentials at startup
- Fields: `tunnel_id`, `credentials_json` (base64-encoded)
- Tunnel token can alternatively be passed via `TUNNEL_TOKEN` environment variable

**GitHub Webhook Security**:
- GitHub sends webhooks with `X-Hub-Signature-256` header (HMAC-SHA256)
- Komodo validates webhook signature against stored secret
- Webhook secret stored in 1Password
- Cloudflare Access policies NOT required for service-to-service webhooks (signature validation sufficient)
- No split-horizon DNS needed (public FQDN resolves to Cloudflare only)

**Label-Driven Configuration**:
- Homepage labels: `homepage.group: "Infrastructure"`, widget for health endpoint
- AutoKuma labels: HTTP monitor on `http://cloudflared:8080/healthcheck`
- No Caddy labels needed (tunnel IS the ingress edge, not a proxied service)
- Keyword monitor for tunnel connection status: `"healthy":true`

**Constitution Compliance**:
- Principle 1 (Management Sacred): Tunnel runs on TrueNAS Swarm, not management VLAN — PASS
- Principle 3 (Identity-Gated): Tunnel provides transport; webhook signature provides authenticity — PASS
- ADR-0002 (Tunnel-Only): Cloudflare Tunnel is the prescribed ingress method — PASS
- Access Invariant 3: External ingress via Cloudflare Tunnel only — PASS
- DNS Invariant 2: No split-horizon overrides — PASS

**Deployment Tier**:
- Cloudflare Tunnel is infrastructure-tier (required for external access)
- Could be placed in `stacks/infrastructure/` alongside Caddy, or `stacks/platform/ingress/`
- Recommendation: `stacks/infrastructure/cloudflared-compose.yaml` (bootstrap dependency)

---

## R4: Technology Best Practices Summary

### Docker Swarm Patterns

| Pattern | Best Practice | Source |
|---------|--------------|--------|
| Secret hydration | `replicated-job` with `restart_policy.condition: none` | ADR-0035 |
| Label placement | Always `deploy.labels`, never container `labels` | ADR-0034 |
| Deployment | Komodo UI for platform/app tier; script for infrastructure | ADR-0022 |
| Image pinning | Full SHA-256 digests, not just version tags | Existing stacks |
| Network isolation | Internal overlay for service-to-service; `proxy_network` for ingress | All stacks |
| Entrypoint wrapper | `set -a && . /secrets/*.env && set +a && exec <cmd>` | All stacks |

### Validation Script Patterns

| Requirement | Best Practice | Source |
|-------------|--------------|--------|
| Shell compatibility | `#!/bin/sh` (POSIX), not `#!/bin/bash` | PRE-DEPLOYMENT-VALIDATION-POLICY.md |
| Execution time | Must complete in < 10 seconds | Governance policy |
| Idempotency | Check before acting, safe to run multiple times | Governance policy |
| No git operations | Komodo handles repository sync | ADR-0022 |
| No deployment | Komodo handles `docker stack deploy` | ADR-0022 |
| Health checks | Test upstream dependencies (1Password Connect API, networks, secrets) | Existing scripts |

### Monitoring Integration

| Component | Health Endpoint | AutoKuma Monitor Type |
|-----------|----------------|----------------------|
| Prometheus | `/-/healthy` | HTTP 200 |
| Grafana | `/api/health` | HTTP 200 |
| Loki | `/ready` | HTTP 200 |
| Authentik | `/` (redirects to login) | HTTP 200,301,302 |
| Cloudflared | `/healthcheck` | HTTP + keyword |

---

## Open Questions (None)

All NEEDS CLARIFICATION items from the Technical Context have been resolved through codebase analysis. No external research was required — the implementation is well-documented in the existing codebase, ADRs, and governance documents.
