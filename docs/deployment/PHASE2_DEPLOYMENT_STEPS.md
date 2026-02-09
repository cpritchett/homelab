# Phase 2: Platform Services Deployment Steps

This guide defines the current Phase 2 deployment pattern for Komodo-managed platform stacks.

## Scope and Current Queue

From `specs/002-label-driven-swarm-infrastructure/spec.md`:

- In progress: Task `#12` - Deploy Authentik SSO platform
- In progress: Task `#14` - Build monitoring stack (Prometheus/Grafana/Loki)
- Pending: Task `#15` - Set up Cloudflare Tunnel for Komodo GitHub webhooks

## Deployment Pattern (Required)

All Phase 2 stacks follow this flow:

1. Configure a stack-specific idempotent pre-deploy validation hook in Komodo.
2. Let Komodo run validation and deployment from Git.
3. Verify service health and external access.

Do not use host-side deployment scripts (`docker stack deploy`) for platform stacks. Per ADR-0022, deployment happens in Komodo.

## Secrets Pattern (Current)

Use this decision order for secrets:

1. Preferred: 1Password Connect (`op-connect-api`) with runtime injection.
2. Fallback: Docker Swarm external secrets when Connect/runtime injection is not viable for a stack.

Notes:
- Old guidance that required manual template creation in this runbook is obsolete.
- If a stack still uses template files in-repo (for example Authentik today), treat them as stack-owned artifacts and validate them via the pre-deploy hook and stack-specific docs.
- Do not use ad-hoc workstation templating steps in this phase runbook.
- One-shot secret-hydration service rules are governed in `docs/governance/PRE-DEPLOYMENT-VALIDATION-POLICY.md`.

## Task #12: Authentik SSO (Execute Now)

Canonical implementation references:

- Stack path: `stacks/platform/auth/authentik/`
- Pre-deploy script: `scripts/validate-authentik-setup.sh`
- Stack deployment guide: `docs/deployment/AUTHENTIK_DEPLOY.md`
- Validation policy: `docs/governance/PRE-DEPLOYMENT-VALIDATION-POLICY.md`

### Komodo Configuration

1. Create/update stack `platform_authentik`.
2. Set run directory to `stacks/platform/auth/authentik/`.
3. Set pre-deploy hook to `scripts/validate-authentik-setup.sh`.
4. Deploy via Komodo and verify services:
   - `secrets-init`
   - `postgresql`
   - `redis`
   - `authentik-server`
   - `authentik-worker`

### Validation Targets

- Pre-deploy hook exits `0`.
- Authentik UI reachable at `https://auth.in.hypyr.space`.
- Stack health is stable after first startup cycle.

## Task #14: Monitoring Stack (Prometheus/Grafana/Loki)

Status: implementation complete; pending Komodo execution in environment.

Canonical implementation references:

- Stack path: `stacks/platform/monitoring/`
- Pre-deploy script: `scripts/validate-monitoring-setup.sh`
- Stack guide: `stacks/platform/monitoring/README.md`

### Komodo Configuration

1. Create/update stack `platform_monitoring`.
2. Set run directory to `stacks/platform/monitoring/`.
3. Set pre-deploy hook to `scripts/validate-monitoring-setup.sh`.
4. Deploy via Komodo and verify services:
   - `op-secrets`
   - `prometheus`
   - `grafana`
   - `loki`

### Validation Targets

- Pre-deploy hook exits `0`.
- Prometheus reachable at `https://prometheus.in.hypyr.space`.
- Grafana reachable at `https://grafana.in.hypyr.space`.
- Loki readiness reachable at `https://loki.in.hypyr.space/ready`.

## Task #15: Cloudflare Tunnel for Komodo GitHub Webhooks

Status: pending implementation.

Expected to follow the same pattern:

1. Add idempotent pre-deploy validation (network/dependency/secret checks).
2. Prefer 1Password Connect for tunnel credentials when viable.
3. Fall back to Swarm secrets if Connect/runtime retrieval is not viable for the chosen tunnel implementation.
4. Deploy through Komodo and verify webhook reachability end-to-end.

## Quick Verification Commands

```bash
# Authentik pre-deploy check (manual test, optional)
sudo /mnt/apps01/repos/homelab/scripts/validate-authentik-setup.sh

# Confirm Authentik services
docker service ls | grep authentik

# Confirm required infra dependencies
docker service ls | grep op-connect
docker network inspect proxy_network >/dev/null
docker network inspect op-connect_op-connect >/dev/null
```

## Related References

- `specs/002-label-driven-swarm-infrastructure/spec.md`
- `docs/governance/SERVICE_DEPLOYMENT_CHECKLIST.md`
- `docs/governance/PRE-DEPLOYMENT-VALIDATION-POLICY.md`
- `docs/adr/ADR-0022-truenas-komodo-stacks.md`
- `docs/adr/ADR-0032-onepassword-connect-swarm.md`
