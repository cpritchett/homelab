# RESTORE_RUNBOOK.md

## Goal

Recover a TrueNAS host (Barbary) after reboot, upgrade, drive failure, or full reinstall.

This runbook assumes:
- Restic backups exist in S3 (SeaweedFS)
- 1Password still holds secrets
- Your homelab repo contains the platform stack definitions under `stacks/`

## Break-glass principles

- Always keep at least one way to reach Komodo and Caddy without depending on Authentik.
  Options:
  - LAN-only hostname not gated by forward-auth
  - direct IP:port from a trusted network
  - temporarily disable forward-auth labels

- Do not make "secrets export" depend on Authentik.
  Secrets export must work before Authentik.

## Restore order (happy path)

### 1) Base OS + pool availability
- Install/upgrade TrueNAS
- Confirm pools import and mount:
  - /mnt/apps01
  - /mnt/data01

### 2) Restore filesystem from Restic
If you are restoring onto empty datasets:
- Create mountpoints:
  - /mnt/apps01/appdata
  - /mnt/apps01/secrets
  - /mnt/data01/appdata

Restore order:
- Restore /mnt/apps01 first (Komodo stacks rely on these paths)
- Restore /mnt/data01 next (stateful services rely on spinning rust storage)

### 3) Bring up Caddy (ingress)
- Deploy Caddy attached to `proxy_network`
- Verify:
  - ports 80/443 exposed
  - wildcard cert issuance still works
  - fallback site responds

### 4) Bring up Komodo
- Deploy Komodo core/mongo/periphery
- Verify komodo UI is reachable (do not gate via Authentik yet)

### 5) Re-materialize secrets (op-export)

**Critical:** This step must happen before Authentik can start, since Authentik credentials come from 1Password.

- Ensure service account token exists at `/mnt/apps01/secrets/op/op.env`:
  - **Preferred:** Restore this file from Restic backup
  - **If not in backup, manually create:**
    1. In 1Password, locate the **service account** used for op-export (under Integrations/Service accounts) and copy its **service account token**.
    2. On the TrueNAS host, create the directory and file:
       ```bash
       mkdir -p /mnt/apps01/secrets/op
       cat > /mnt/apps01/secrets/op/op.env << 'EOF'
       OP_SERVICE_ACCOUNT_TOKEN=<PASTE_YOUR_SERVICE_ACCOUNT_TOKEN_HERE>
       VAULT=homelab
       DEST_ROOT=/mnt/apps01/secrets
       EOF
       chmod 600 /mnt/apps01/secrets/op/op.env
       ```
    3. Verify permissions are restrictive (600) so only the appropriate user can read it.

- Once the token file exists, run the op-export job stack via Komodo (or manually: `docker compose up`).

Verify on host:
- `/mnt/apps01/secrets/authentik/*.env` (should contain authentik.env and postgres.env)
- `/mnt/apps01/secrets/restic/*.env` (should contain restic.env)

### 6) Bring up Authentik
- Deploy Authentik stack
- Verify auth UI and admin login

### 7) Bring up observability
- Deploy Uptime Kuma and verify status UI

### 8) Re-enable forward-auth (optional)
Only after Authentik is healthy:
- apply forward-auth labels to the apps you want gated

## If Authentik is broken

- Remove forward-auth labels (or gate nothing) until Authentik is healthy again.
- Keep Komodo reachable directly for recovery operations.

## Common failure modes

### Permission denied on Postgres data directory
Fix dataset ownership/ACLs so the Postgres container user can read/write its data directory.

### Restic cannot access S3
Validate:
- AWS_ENDPOINT
- credentials
- routing/DNS from Barbary to the S3 host

Test with snapshots listing (no writes).

### op-export cannot read vault
Service account token lacks access or tags are wrong.
Confirm the items are tagged `stack:<name>` and titles end with `.env`.

## Post-restore validation checklist

- Caddy:
  - wildcard cert present
  - at least one app route works
- Komodo:
  - can start/stop stacks
- Secrets:
  - env files exist for each stack
- Authentik:
  - admin login works, MFA enabled
- Backups:
  - restic snapshots list works
