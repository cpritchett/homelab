# PLATFORM_BOOTSTRAP.md

## Purpose

Bootstrap the TrueNAS + Komodo "platform services" layer (non-Kubernetes) that supports all application stacks.

Platform services included:
- Caddy (already running)
- 1Password Connect Server (secret management via HTTP API)
- Authentik (SSO/MFA)
- Uptime Kuma (basic monitoring)
- Restic -> S3 (backups)

This is intentionally small. Everything else belongs in application stacks.

## Assumptions

- TrueNAS SCALE host
- Komodo manages Compose stacks
- Caddy is already deployed and attached to the external Docker network `proxy_network`
- DNS works for `*.in.hypyr.space`
- `/mnt/apps01` is fast storage, `/mnt/data01` is spinning rust
- Secrets are stored in 1Password and accessed via Connect Server API (no pre-materialization needed)

## Repo conventions (this repo)

Your repo contains Kubernetes homelab content at the root. Docker/Komodo stacks live under:

- `stacks/` (this document assumes this is the base)
- Each stack uses `compose.yaml`

Relevant layout:

- `stacks/platform/secrets/op-connect/compose.yaml`
- `stacks/platform/auth/authentik/compose.yaml`
- `stacks/platform/observability/uptime-kuma/compose.yaml`
- `stacks/platform/backups/restic/compose.yaml`
- `stacks/scripts/op-export-stack-env.sh`
- `stacks/scripts/restic/run.sh`
- `stacks/docs/PLATFORM_BOOTSTRAP.md`
- `stacks/docs/RESTORE_RUNBOOK.md`
- `stacks/docs/CADDY_FORWARD_AUTH_LABELS.md`

## Step 0: Host directories (one-time)

Run on the TrueNAS host:

```
mkdir -p /mnt/apps01/appdata
mkdir -p /mnt/apps01/appdata/proxy
mkdir -p /mnt/apps01/secrets
mkdir -p /mnt/apps01/appdata/restic/cache

mkdir -p /mnt/apps01/appdata/uptime-kuma

mkdir -p /mnt/apps01/appdata/authentik
mkdir -p /mnt/apps01/appdata/authentik/media
mkdir -p /mnt/apps01/appdata/authentik/custom-templates

mkdir -p /mnt/data01/appdata/authentik
mkdir -p /mnt/data01/appdata/authentik/postgres
mkdir -p /mnt/data01/appdata/authentik/redis
```

Notes:
- Postgres on rust (`/mnt/data01`) is fine and matches your preference.
- Redis can be ephemeral; persistence is optional. If you want persistence, mount it (see Authentik compose notes).
- Restic scripts (`run.sh`, `excludes.txt`) are bundled in the stack directory; Komodo handles syncing them automatically.

## Step 1: 1Password Connect Server credentials

On your **workstation** (where `op` CLI is installed):

```bash
# List vaults to get vault ID
op vault list

# Create Connect server credentials
op connect server create homelab-truenas --vaults homelab

# Save the output JSON as 1password-credentials.json
```

Copy credentials to TrueNAS:

```bash
# Create secrets directory
ssh truenas "mkdir -p /mnt/apps01/secrets/op"

# Copy credentials
scp 1password-credentials.json truenas:/mnt/apps01/secrets/op/

# Set permissions
ssh truenas "chmod 600 /mnt/apps01/secrets/op/1password-credentials.json"
```

**Important:** This credentials file provides full vault access. Keep it secure and never commit to git.

## Step 2: Deploy 1Password Connect Server

In Komodo, deploy:

- `stacks/platform/secrets/op-connect/compose.yaml`

Verify on host:

```bash
docker service ls | grep op-connect
curl http://localhost:8080/health
```

Both `op-connect-api` and `op-connect-sync` should be healthy.

## Step 3: Create shared Connect token

Create one token and store as a Swarm secret for all stacks to use:

```bash
# On your workstation
op connect token create homelab-stacks --server homelab-truenas --vault homelab

# Store as Swarm secret on TrueNAS
echo "<token-from-above>" | ssh truenas "docker secret create op_connect_token -"

# Verify
ssh truenas "docker secret ls | grep op_connect_token"
```

All stacks will reference this shared `op_connect_token` secret.

## Step 4: Configure 1Password items (secret source)

All items live in the `homelab` vault. Use standard 1Password item format (not tagged for export).

### Required items

1) `authentik-stack` item with fields:
- secret_key (generate with `openssl rand -base64 32`)
- bootstrap_email (required for initial setup)
- bootstrap_password (required for initial setup)
- postgres_password (for database)
- postgres_user (default: authentik)
- postgres_db (default: authentik)

Reference format in templates: `op://homelab/authentik-stack/secret_key`

2) `restic` item with fields:
- repository (S3 URL)
- password (restic repo password)
- aws_access_key_id
- aws_secret_access_key
- aws_endpoint
- aws_default_region

Reference format in templates: `op://homelab/restic/repository`

## Step 5: Deploy Authentik (with Connect integration)

**Note:** For now, Authentik still uses env files. Full migration to `op inject` pattern is documented in `stacks/platform/auth/authentik/MIGRATION.md`.

Deploy:

- `stacks/platform/auth/authentik/compose.yaml`

Verify:
- `https://auth.in.hypyr.space` loads through Caddy
- Bootstrap login works
- Create a second admin user immediately
- Enable MFA for both admin users

## Step 6: Deploy Uptime Kuma (basic monitoring)

Deploy:

- `stacks/platform/observability/uptime-kuma/compose.yaml`

Verify:
- `https://status.in.hypyr.space` loads
- Add monitors for:
  - auth.in.hypyr.space
  - komodo.in.hypyr.space
  - barbary.in.hypyr.space
  - any other "tier-0" UIs

## Step 7: Deploy backups (Restic) - run manually first

Deploy:

- `stacks/platform/backups/restic/compose.yaml`

Run manually first:
- RESTIC_TASK=backup
- RESTIC_TASK=snapshots
- RESTIC_TASK=check

Confirm snapshots exist in your S3 backend (SeaweedFS).

Only after that should you schedule:
- Daily: backup
- Weekly: prune
- Monthly: check

## Step 8: Protect apps with Authentik (per-app opt-in)

Use forward-auth in Caddy only on apps you choose.

Start with:
- komodo.in.hypyr.space

Process:
1) Create Authentik Proxy Provider for the app
2) Deploy the outpost (proxy outpost)
3) Add Caddy forward-auth labels to the app route (see stacks/docs/CADDY_FORWARD_AUTH_LABELS.md)
4) Confirm you can still reach the app via direct LAN address as a break-glass path (or keep a separate non-auth hostname)

## "What goes top level" rule

Top level (platform) should be:
- ingress
- auth
- secrets materialization
- monitoring
- backups

Everything else is an app stack.
