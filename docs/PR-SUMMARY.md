# PR Summary (main..feat/stacks-truenas)

This document summarizes all changes on this branch relative to `main`.

## Overview

This branch adds a TrueNAS-focused stacks system with:
- Docker Compose stack definitions for a Caddy proxy and Harbor registry
- Deployment scripts for sparse checkout + automated rollout
- TrueNAS init/cron integration
- Supporting documentation

## Files Added

### Stack definitions
- `stacks/proxy/compose.yml` — Caddy reverse proxy + docker-socket-proxy on `proxy_network`
- `stacks/proxy/.env.tpl` — 1Password references for Caddy secrets and TZ
- `stacks/proxy/render-env.sh` — renders `.env` from `.env.tpl` using `op-inject`
- `stacks/harbor/compose.yml` — Harbor registry stack (all services on Docker networks; no host ports)
- `stacks/harbor/.env.tpl` — 1Password references for Harbor secrets + Cloudflare DNS token
- `stacks/harbor/render-env.sh` — renders `.env` from `.env.tpl` using `op-inject`

### Deployment utilities
- `stacks/_bin/op-inject` — runs 1Password CLI in a container as the host user
- `stacks/_bin/deploy-stack` — deploy a single stack directory (render .env, compose pull/up)
- `stacks/_bin/deploy-all` — deploy stacks in dependency order
- `stacks/_bin/sync-and-deploy` — sparse-checkout repo and deploy (intended for NAS)
- `stacks/_bin/ensure-harbor-datasets` — creates/normalizes ZFS datasets + mountpoints for Harbor
- `stacks/_bin/README.md` — documentation for stack helper scripts
- `scripts/test-talos-templates.sh` — local Talos render validation script (mirrors CI)

### TrueNAS system hooks
- `stacks/_system/init/10-homelab-stacks.sh` — boot-time deploy hook (async + timeout)
- `stacks/_system/cron/deploy-stacks.sh` — scheduled deploy hook (flocked)
- `stacks/_system/README.md` — docs for TrueNAS integration

### Registry
- `stacks/registry.toml` — explicit stack registry with dependencies

### Documentation
- `docs/STACKS.md` — NAS stacks overview and workflow
- `ops/runbooks/stacks-deployment.md` — runbook for NAS stack deployment (registry-based)
- `docs/adr/ADR-0021-stacks-registry-required.md` — ADR requiring registry for NAS stacks

## Files Updated

- `.gitignore` — allow committed `.env.tpl` files
- `stacks/README.md` — reorganized around deployment-type structure and registry-driven order
- `scripts/run-all-gates.sh` — aligns local gates with CI checks
- `contracts/invariants.md` — require NAS stacks to be registered
- `requirements/workflow/repository-structure.md` — registry requirement + ADR link

## Notable Behavior/Design Notes

- Stack deployment is GitHub-driven via sparse checkout, keeping the NAS clean.
- Deployment order is driven by `stacks/registry.toml` (dependency graph), not naming conventions.
- Caddy uses docker-socket-proxy for label-based routing; `proxy_network` is external and must exist.
- Harbor stack uses syslog to `harbor-log` aggregator, with small log files to limit disk use.
- TrueNAS hooks are intentionally independent and idempotent.

## Branch-specific Adjustments (this session)

- `stacks/harbor/.env.tpl` now consistently references `CLOUDFLARE_API_TOKEN`.
- `stacks/proxy/compose.yml` clarifies HTTPS upstream for Barbary reverse proxy.
- `stacks/_bin/ensure-harbor-datasets` no longer deletes `root.crt` on every run; it now only creates a placeholder if missing and errors on non-file paths.
