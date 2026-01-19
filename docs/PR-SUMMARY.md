# PR Summary (updated for Komodo stacks)

This document summarizes all changes on this branch relative to `main`.

## Overview

This branch replaces the registry/script-driven stacks flow with Komodo-managed stacks:
- Compose stack definitions for proxy and authentik (Komodo-compatible)
- No registry.toml, no host-side deploy scripts
- Documentation updated for Komodo deployment

## Files Added

### Stack definitions
- `stacks/proxy/compose.yml` — Caddy reverse proxy + docker-socket-proxy on `proxy_network`
- `stacks/proxy/.env.example` — env keys for proxy stack (Komodo secrets/vars)
- `stacks/authentik/compose.yml` — Authentik stack (bundled Postgres/Redis) routed via proxy
- `stacks/authentik/.env.example` — env keys for Authentik

### Documentation
- `docs/STACKS.md` — NAS stacks via Komodo
- `ops/runbooks/stacks-deployment.md` — Komodo deployment flow
- `docs/adr/ADR-0022-truenas-komodo-stacks.md` — supersedes ADR-0021

## Files Updated

- `contracts/invariants.md` — switch to Komodo-managed stacks; no registry
- `requirements/workflow/repository-structure.md` — remove registry requirement
- `requirements/workflow/spec.md` — link ADR-0022
- `docs/STACKS.md` — Komodo deployment docs
- `ops/runbooks/stacks-deployment.md` — Komodo flow

## Notable Behavior/Design Notes

- Stack deployment is driven by TrueNAS Komodo pulling from GitHub; no host scripts needed.
- Proxy stack still expects external network `proxy_network`.
- Authentik stack binds Postgres/Redis locally and fronts through proxy labels.

## Branch-specific Adjustments (this session)

- `stacks/harbor/.env.tpl` now consistently references `CLOUDFLARE_API_TOKEN`.
- `stacks/proxy/compose.yml` clarifies HTTPS upstream for Barbary reverse proxy.
- `stacks/_bin/ensure-harbor-datasets` no longer deletes `root.crt` on every run; it now only creates a placeholder if missing and errors on non-file paths.
