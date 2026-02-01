# Restic Backup Stack

Restic backup job that runs via Komodo with secrets templated from 1Password.

## Quick Start

Per [ADR-0022](../../../../docs/adr/ADR-0022-truenas-komodo-stacks.md), stacks must be deployable through Komodo without external dependencies.

### Prerequisites

1. **Host directory + ownership**:
   ```bash
   mkdir -p /mnt/apps01/appdata/restic/cache
   chown -R 0:0 /mnt/apps01/appdata/restic/cache
   ```

   Optional helper (run on TrueNAS): `stacks/scripts/set-host-permissions.sh`

2. **1Password Connect must be running**:
   - Deploy `op-connect` stack first
   - Ensure `op_connect_token` Swarm secret exists

3. **Deploy via Komodo**:
   - Add this stack directory in Komodo
   - Populate env/secret values
   - Deploy (run as a job)

## Notes

- Restic runs as root (UID/GID `0:0`).
- Sources are mounted read-only from `/mnt/apps01` and `/mnt/data01`.
