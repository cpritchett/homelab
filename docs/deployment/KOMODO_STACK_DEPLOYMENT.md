# Komodo Stack Deployment Guide

This document is the deployment routing guide for Komodo-managed stacks.

It consolidates where to find authoritative instructions and removes duplicated per-stack runbooks from this file.

## Canonical Sources

Use these documents in order:

1. Governance contract: `docs/governance/agent-contract.md`
2. Deployment policy: `docs/governance/PRE-DEPLOYMENT-VALIDATION-POLICY.md`
3. Service checklist: `docs/governance/SERVICE_DEPLOYMENT_CHECKLIST.md`
4. Phase 2 execution guide: `docs/deployment/PHASE2_DEPLOYMENT_STEPS.md`
5. Stack-specific guide (example): `docs/deployment/AUTHENTIK_DEPLOY.md`

## Required Deployment Pattern

For platform/application stacks:

1. Configure stack from repository in Komodo.
2. Set run directory to the stack path.
3. Configure idempotent pre-deploy hook (`scripts/validate-<stack>-setup.sh`) when required by policy.
4. Deploy via Komodo only.
5. Verify service health and external reachability.

Per ADR-0022, do not use host-side deployment scripts for platform/application stacks.

## Secrets Strategy

Apply this order:

1. Prefer 1Password Connect runtime retrieval/injection.
2. Use Docker Swarm external secrets when Connect/runtime retrieval is not viable for a stack.

Do not add ad-hoc workstation templating workflows to Komodo deployment docs.

## Stack Paths

- Infrastructure stacks: `stacks/infrastructure/`
- Platform stacks: `stacks/platform/`
- Application stacks: `stacks/applications/` (when present)

## Common Validation Commands

```bash
# Required networks for proxy + Connect-integrated stacks
docker network inspect proxy_network >/dev/null
docker network inspect op-connect_op-connect >/dev/null

# Required secret examples
docker secret inspect op_connect_token >/dev/null
docker secret inspect CLOUDFLARE_API_TOKEN >/dev/null
```

## Current Phase 2 Queue

Reference: `specs/002-label-driven-swarm-infrastructure/spec.md`

- `#12` Deploy Authentik SSO platform
- `#14` Build monitoring stack (Prometheus/Grafana/Loki) - implementation ready at `stacks/platform/monitoring/`
- `#15` Set up Cloudflare Tunnel for Komodo GitHub webhooks

## Migration Note

If you find instructions here that conflict with stack-specific docs under `stacks/platform/...`, the stack-specific docs and governance policies are authoritative. Open a doc cleanup PR to remove drift.
