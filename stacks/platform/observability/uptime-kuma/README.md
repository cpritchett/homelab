# Uptime Kuma Stack

Uptime Kuma monitoring with Caddy reverse proxy integration.

## Quick Start

Per [ADR-0022](../../../../docs/adr/ADR-0022-truenas-komodo-stacks.md), stacks must be deployable through Komodo without external dependencies.

### Prerequisites

1. **External Docker network** (create once on host):
   ```bash
   docker network create proxy_network
   ```

2. **Host directory + ownership**:
   ```bash
   mkdir -p /mnt/apps01/appdata/uptime-kuma
   chown -R 1000:1000 /mnt/apps01/appdata/uptime-kuma
   ```

   Optional helper (run on TrueNAS): `stacks/scripts/set-host-permissions.sh`

3. **Deploy via Komodo**:
   - Add this stack directory in Komodo
   - Deploy

## Notes

- Uptime Kuma runs as UID/GID `1000:1000`.
- `proxy_network` alias: `uptime-kuma`.
