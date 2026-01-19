# Runbook: NAS Stacks Deployment (TrueNAS)

**Scope:** Docker Compose stacks deployed on NAS hosts via the homelab repo.

## Summary

Stacks are deployed from this repo using a registry file (`stacks/registry.conf`) that defines
stack paths and dependencies. Deployment uses a sparse checkout on the NAS and renders
secrets via 1Password before running Docker Compose.

## Prerequisites

- NAS host is LAN-only (no WAN exposure).
- Docker installed and running on the NAS.
- 1Password service account token file exists and is readable.
  - Default path: `/mnt/apps01/appdata/secrets/1password/op_service_account_token`
  - Override with `OP_TOKEN_FILE`
- External Docker network exists (run once):
  - `docker network create proxy_network`

## Registry (Order + Dependencies)

Deployment order is controlled by `stacks/registry.conf` using dependency relationships:

```
# Format: stack_name:path:depends_on (comma-separated deps, empty for none)
proxy:00-proxy:
harbor:20-harbor:proxy
```

**Ordering Logic:**
- Stacks are sorted using topological sort based on dependencies
- Dependency resolution via `depends_on` is then applied to ensure dependencies deploy before dependents
- Both mechanisms work together: `order` provides explicit sequencing, `depends_on` enforces constraints

## One-time Setup (Harbor datasets)

Run the dataset initializer on the NAS (safe to re-run):

```bash
/mnt/apps01/appdata/stacks/homelab/stacks/_bin/ensure-harbor-datasets
```

This creates/normalizes ZFS datasets and mountpoints under:
- `/mnt/apps01/appdata/harbor/runtime/...`

## Manual Deployment

```bash
/mnt/apps01/appdata/stacks/homelab/stacks/_bin/sync-and-deploy
```

What it does:
- Sparse-checkouts `stacks/` + `docs/` from GitHub
- Installs `op-inject` into `/mnt/apps01/appdata/bin/`
- Renders per-stack `.env` from `.env.tpl`
- Deploys stacks in dependency order

## TrueNAS Integration (Optional)

### Boot-time (init script)

Configure a Post-Init Script in the TrueNAS UI:

- Script: `/mnt/apps01/appdata/stacks/homelab/stacks/_system/init/10-homelab-stacks.sh`
- When: `Post Init`

### Scheduled updates (cron)

Configure a cron job in the TrueNAS UI:

- Command: `/mnt/apps01/appdata/stacks/homelab/stacks/_system/cron/deploy-stacks.sh`
- User: `root`
- Schedule: e.g., daily at 03:00

## Troubleshooting

### Check rendered env files

Each stack directory should have a `.env` after rendering:

```bash
ls -la /mnt/apps01/appdata/stacks/homelab/stacks/proxy/.env
ls -la /mnt/apps01/appdata/stacks/homelab/stacks/harbor/.env
```

### Re-render secrets

```bash
cd /mnt/apps01/appdata/stacks/homelab/stacks/proxy && ./render-env.sh
cd /mnt/apps01/appdata/stacks/homelab/stacks/harbor && ./render-env.sh
```

### Check deploy order

```
cat /mnt/apps01/appdata/stacks/homelab/stacks/registry.conf
```

### Docker status

```bash
sudo docker compose ps
sudo docker logs caddy --tail=200
sudo docker logs harbor-core --tail=200
```
