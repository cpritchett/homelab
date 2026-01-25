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
- Restore /mnt/data01 next (stateful services rely on rust storage)

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
- Ensure service account token exists in /mnt/apps01/secrets/op/op.env (restore or re-create)
- Run the op-export job stack via Komodo

Verify on host:
- /mnt/apps01/secrets/authentik/*.env
- /mnt/apps01/secrets/restic/*.env

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
