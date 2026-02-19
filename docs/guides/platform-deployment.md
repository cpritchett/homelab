# Platform Deployment Guide

Deploy the platform services layer on top of the infrastructure tier (Caddy, 1Password Connect, Komodo).

## Overview & Assumptions

- TrueNAS SCALE host with Docker Swarm initialized (Phase 1 complete)
- Caddy is already deployed and attached to `proxy_network`
- 1Password Connect is running and accessible via `op-connect-api:8080`
- Komodo manages all platform-tier stacks — do not use `docker stack deploy` directly
- DNS works for `*.in.hypyr.space`
- `/mnt/apps01` is fast storage (SSD), `/mnt/data01` is spinning rust

## Prerequisites

- [ ] Phase 1 complete ([TrueNAS Bootstrap Guide](truenas-bootstrap.md))
- [ ] Caddy, op-connect, and Komodo stacks running
- [ ] `op_connect_token` Swarm secret exists
- [ ] DNS resolving for `*.in.hypyr.space`

## Deployment Order

All platform stacks follow this pattern:

1. Configure a stack-specific idempotent pre-deploy validation hook in Komodo
2. Let Komodo run validation and deployment from Git
3. Verify service health and external access

### Secrets Pattern

Use this decision order:

1. **Preferred:** 1Password Connect (`op-connect-api`) with runtime `op inject`
2. **Fallback:** Docker Swarm external secrets when Connect/runtime injection is not viable

If a stack uses template files in-repo (e.g., Authentik), treat them as stack-owned artifacts validated via the pre-deploy hook.

## Service-Specific Steps

### 1. Authentik SSO

**Stack path:** `stacks/platform/auth/authentik/`
**Pre-deploy script:** `scripts/validate-authentik-setup.sh`
**Detailed guide:** [Authentik Deployment](authentik-deployment.md)

**Host directories (one-time):**

```bash
mkdir -p /mnt/apps01/appdata/authentik/{media,custom-templates}
mkdir -p /mnt/apps01/appdata/authentik/{postgres,redis}
```

**1Password items required:** `authentik-stack` in homelab vault with fields:
- `secret_key`, `bootstrap_email`, `bootstrap_password`, `postgres_password`

**Komodo configuration:**

1. Create stack `platform_authentik`
2. Set run directory to `stacks/platform/auth/authentik/`
3. Set pre-deploy hook to `scripts/validate-authentik-setup.sh`
4. Deploy and verify services: `secrets-init`, `postgresql`, `redis`, `authentik-server`, `authentik-worker`

**Validation:**
- Pre-deploy hook exits `0`
- Authentik UI reachable at `https://auth.in.hypyr.space`
- Bootstrap login works → create second admin → enable MFA

### 2. Monitoring Stack (Prometheus/Grafana/Loki)

**Stack path:** `stacks/platform/monitoring/`
**Pre-deploy script:** `scripts/validate-monitoring-setup.sh`
**Detailed guide:** `stacks/platform/monitoring/README.md`

**Komodo configuration:**

1. Create stack `platform_monitoring`
2. Set run directory to `stacks/platform/monitoring/`
3. Set pre-deploy hook to `scripts/validate-monitoring-setup.sh`
4. Deploy and verify services: `op-secrets`, `prometheus`, `grafana`, `loki`

**Validation:**
- Prometheus at `https://prometheus.in.hypyr.space`
- Grafana at `https://grafana.in.hypyr.space`
- Loki readiness at `https://loki.in.hypyr.space/ready`

### 3. Observability Stack (Homepage + Uptime Kuma)

**Stack path:** `stacks/platform/observability/`

**Host directories (one-time):**

```bash
mkdir -p /mnt/apps01/appdata/homepage/{config,icons,images}
mkdir -p /mnt/apps01/appdata/uptime-kuma
chown -R 1000:1000 /mnt/apps01/appdata/homepage
chown -R 1000:1000 /mnt/apps01/appdata/uptime-kuma
```

**Validation:**
- Homepage at `https://home.in.hypyr.space`
- Uptime Kuma at `https://status.in.hypyr.space`
- Add monitors for tier-0 services

### 4. Backups (Restic → S3)

**Stack path:** `stacks/platform/backups/restic/`

**1Password items required:** `restic` in homelab vault with fields:
- `repository`, `password`, `aws_access_key_id`, `aws_secret_access_key`, `aws_endpoint`, `aws_default_region`

**Run manually first before scheduling:**

```bash
# Test backup
RESTIC_TASK=backup  # run via Komodo
RESTIC_TASK=snapshots
RESTIC_TASK=check
```

Confirm snapshots exist in S3 backend, then schedule: daily backup, weekly prune, monthly check.

### 5. Cloudflare Tunnel (Komodo GitHub Webhooks)

**Status:** Follow same pattern — pre-deploy validation, prefer 1Password Connect for tunnel credentials, deploy through Komodo.

## Protecting Apps with Authentik

Use forward-auth in Caddy on a per-app opt-in basis. Start with `komodo.in.hypyr.space`.

Process:
1. Create Authentik Proxy Provider for the app
2. Deploy the outpost (proxy outpost)
3. Add Caddy forward-auth labels (see [Forward Auth Guide](forward-auth.md))
4. Keep a break-glass path via direct LAN address

## Quick Verification Commands

```bash
# Authentik pre-deploy check
sudo /mnt/apps01/repos/homelab/scripts/validate-authentik-setup.sh

# Service status
docker service ls | grep -E 'authentik|monitoring|observability'

# Infrastructure dependencies
docker service ls | grep op-connect
docker network inspect proxy_network >/dev/null && echo "proxy_network OK"
docker network inspect op-connect_op-connect >/dev/null && echo "op-connect OK"
```

## Platform Tier Rule

Top-level platform services should be limited to:
- Ingress (Caddy)
- Auth (Authentik)
- Secrets (1Password Connect)
- Monitoring (Prometheus/Grafana/Loki + Uptime Kuma)
- Backups (Restic)

Everything else is an application stack.

## Related References

- [Service Deployment Checklist](../governance/SERVICE_DEPLOYMENT_CHECKLIST.md)
- [Pre-Deployment Validation Policy](../governance/PRE-DEPLOYMENT-VALIDATION-POLICY.md)
- [ADR-0022: Komodo-Managed Stacks](../adr/ADR-0022-truenas-komodo-stacks.md)
- [ADR-0032: 1Password Connect for Swarm](../adr/ADR-0032-onepassword-connect-swarm.md)
