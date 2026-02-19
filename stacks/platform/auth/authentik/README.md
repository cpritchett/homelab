# Authentik Stack

Authentik identity provider with bundled Postgres + Redis, routed through Caddy.

## Quick Start

Per [ADR-0022](../../../../docs/adr/ADR-0022-truenas-komodo-stacks.md), stacks must be deployable through Komodo without external dependencies.

### Prerequisites

1. **External Docker network** (create once on host):
   ```bash
   docker network create proxy_network
   ```

2. **Host directories + ownership**:
   ```bash
   mkdir -p /mnt/apps01/appdata/authentik/postgres
   mkdir -p /mnt/apps01/appdata/authentik/redis
   mkdir -p /mnt/apps01/appdata/authentik/media
   mkdir -p /mnt/apps01/appdata/authentik/custom-templates

   chown -R 999:999 /mnt/apps01/appdata/authentik/postgres
   chown -R 999:1000 /mnt/apps01/appdata/authentik/redis
   chown -R 1000:1000 /mnt/apps01/appdata/authentik/media
   chown -R 1000:1000 /mnt/apps01/appdata/authentik/custom-templates
   ```

   Optional helper (run on TrueNAS): `stacks/scripts/set-host-permissions.sh`

3. **1Password Connect must be running**:
   - Deploy `op-connect` stack first
   - Ensure `op_connect_token` Swarm secret exists

4. **Deploy via Komodo**:
   - Add this stack directory in Komodo
   - Populate env/secret values
   - Deploy

## Notes

- Postgres runs as UID/GID `999:999`.
- Redis runs as UID/GID `999:1000`.
- Authentik server/worker runs as UID/GID `1000:1000`.
- `proxy_network` alias: `authentik-server`.
