# Forgejo Git + Container Registry Stack

Self-contained Forgejo stack providing:
- Git repository hosting
- Built-in container registry
- SSH access
- Caddy reverse proxy integration

## Quick Start

Per [ADR-0022](../../../../docs/adr/ADR-0022-truenas-komodo-stacks.md), stacks must be deployable through Komodo without external dependencies.

### Prerequisites

1. **External Docker network** (create once on host):
   ```bash
   docker network create proxy_network
   ```

2. **Host directories**:
   ```bash
   mkdir -p /mnt/apps01/appdata/forgejo
   mkdir -p /mnt/data01/appdata/forgejo/postgres
   chown -R 1000:1000 /mnt/apps01/appdata/forgejo
   chown -R 999:999 /mnt/data01/appdata/forgejo/postgres
   chmod 755 /mnt/apps01/appdata/forgejo
   chmod 755 /mnt/data01/appdata/forgejo
   ```

   Optional helper (run on TrueNAS): `stacks/scripts/set-host-permissions.sh`

3. **Create secrets** in 1Password:
   - Create item "forgejo" (tagged `stacks`):
     ```
     postgres_password: <secure-password>
     FORGEJO_SECRET_KEY: <generate with forgejo generate secret SECRET_KEY>
     FORGEJO_INTERNAL_TOKEN: <generate with forgejo generate secret INTERNAL_TOKEN>
     FORGEJO_DB_PASSWORD: <secure-password>
     ```
   - Ensure `cloudflare-stacks` item exists with `api_token` field

4. **1Password Connect must be running**:
   - Deploy `op-connect` stack first
   - Ensure `op_connect_token` Swarm secret exists

5. **Deploy via Komodo**:
   - Add this stack directory in Komodo
   - Populate env/secret values
   - Deploy

## Usage

### Initial Setup

1. Access Forgejo at `https://git.in.hypyr.space`
2. Create initial admin account
3. Create organization/repositories as needed

### Container Registry Access

Push images to the registry:
```bash
docker login git.in.hypyr.space
docker tag myimage:latest git.in.hypyr.space/username/myimage:latest
docker push git.in.hypyr.space/username/myimage:latest
```

Then reference in compose files:
```yaml
image: git.in.hypyr.space/username/myimage:latest
```

### SSH Access

Clone repositories via SSH:
```bash
git clone ssh://git@git.in.hypyr.space:3022/username/repo.git
```

## Architecture Notes

- **Database**: PostgreSQL 18 (persistent storage on `/mnt/data01`)
- **Git data**: Stored on `/mnt/apps01/appdata/forgejo`
- **Registry**: Built into Forgejo; no separate service
- **Networking**: Connected to `proxy_network` for Caddy routing
- **Reverse proxy**: Caddy handles HTTPS termination and DNS challenge

## Troubleshooting

### Container registry not working

1. Verify `CONTAINER_REGISTRY_ENABLED=true` in environment
2. Check Forgejo logs: `docker logs forgejo`
3. Ensure DNS resolves `git.in.hypyr.space` to NAS host

### SSH access failing

1. Verify SSH port is correctly exposed (default 3022)
2. Check SSH key is added to Forgejo account
3. Test connectivity: `ssh -v git@git.in.hypyr.space -p 3022`
