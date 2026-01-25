# PLATFORM_BOOTSTRAP.md

## Purpose

Bootstrap the TrueNAS + Komodo "platform services" layer (non-Kubernetes) that supports all application stacks.

Platform services included:
- Caddy (already running)
- 1Password -> env materializer (op-export job)
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
- Secrets are stored in 1Password and materialized to `/mnt/apps01/secrets/<stack>/*.env`

## Repo conventions (this repo)

Your repo contains Kubernetes homelab content at the root. Docker/Komodo stacks live under:

- `stacks/` (this document assumes this is the base)
- Each stack uses `compose.yaml`

Relevant layout:

- `stacks/platform/secrets/op-export/compose.yaml`
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
mkdir -p /mnt/apps01/secrets
mkdir -p /mnt/apps01/scripts/restic
mkdir -p /mnt/apps01/appdata/restic/cache

mkdir -p /mnt/apps01/appdata/uptime-kuma

mkdir -p /mnt/data01/appdata/authentik
mkdir -p /mnt/data01/appdata/authentik/postgres
mkdir -p /mnt/data01/appdata/authentik/redis
mkdir -p /mnt/data01/appdata/authentik/media
mkdir -p /mnt/data01/appdata/authentik/custom-templates
```

Notes:
- Postgres on rust (`/mnt/data01`) is fine and matches your preference.
- Redis can be ephemeral; persistence is optional. If you want persistence, mount it (see Authentik compose notes).

## Step 1: 1Password items (source of truth)

All items live in the `homelab` vault.

### Required items

1) `op.env` (tag: `stack:op`)
Fields:
- OP_SERVICE_ACCOUNT_TOKEN
- VAULT=homelab
- DEST_ROOT=/mnt/apps01/secrets

2) `authentik.env` (tag: `stack:authentik`)
Fields:
- AUTHENTIK_SECRET_KEY
- AUTHENTIK_BOOTSTRAP_EMAIL
- AUTHENTIK_BOOTSTRAP_PASSWORD
- AUTHENTIK_POSTGRESQL__PASSWORD  (same value as POSTGRES_PASSWORD)

Optional (recommended later):
- AUTHENTIK_EMAIL__HOST
- AUTHENTIK_EMAIL__PORT
- AUTHENTIK_EMAIL__USERNAME
- AUTHENTIK_EMAIL__PASSWORD
- AUTHENTIK_EMAIL__USE_TLS
- AUTHENTIK_EMAIL__FROM

3) `postgres.env` (tag: `stack:authentik`)
Fields:
- POSTGRES_DB=authentik
- POSTGRES_USER=authentik
- POSTGRES_PASSWORD

4) `restic.env` (tag: `stack:restic`)
Fields:
- RESTIC_REPOSITORY
- RESTIC_PASSWORD
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_ENDPOINT
- AWS_DEFAULT_REGION

## Step 2: Materialize env files (op-export job)

In Komodo, deploy and run:

- `stacks/platform/secrets/op-export/compose.yaml`

Verify on host:

```
ls /mnt/apps01/secrets/authentik
ls /mnt/apps01/secrets/restic
```

Expected:
- `/mnt/apps01/secrets/authentik/authentik.env`
- `/mnt/apps01/secrets/authentik/postgres.env`
- `/mnt/apps01/secrets/restic/restic.env`

If missing: stop and fix op-export and 1Password items before proceeding.

## Step 3: Deploy Authentik (do not gate anything yet)

Deploy:

- `stacks/platform/auth/authentik/compose.yaml`

Verify:
- `https://auth.in.hypyr.space` loads through Caddy
- Bootstrap login works
- Create a second admin user immediately
- Enable MFA for both admin users
- Create an "Operators" group (or similar) and only grant admin roles to that group

Do not protect Komodo until Authentik is stable and you have two admin identities with MFA.

## Step 4: Deploy observability (Uptime Kuma)

Deploy:

- `stacks/platform/observability/uptime-kuma/compose.yaml`

Verify:
- `https://status.in.hypyr.space` loads
- Add monitors for:
  - auth.in.hypyr.space
  - komodo.in.hypyr.space
  - barbary.in.hypyr.space
  - any other "tier-0" UIs

## Step 5: Deploy backups (Restic) - run manually first

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

## Step 6: Protect apps with Authentik (per-app opt-in)

Use forward-auth in Caddy only on apps you choose.

Start with:
- komodo.in.hypyr.space

Process:
1) Create Authentik Proxy Provider for the app
2) Deploy the outpost (proxy outpost)
3) Add Caddy forward-auth labels to the app route (see docs/CADDY_FORWARD_AUTH_LABELS.md)
4) Confirm you can still reach the app via direct LAN address as a break-glass path (or keep a separate non-auth hostname)

## "What goes top level" rule

Top level (platform) should be:
- ingress
- auth
- secrets materialization
- monitoring
- backups

Everything else is an app stack.
