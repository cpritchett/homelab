# TrueNAS Init Script Setup

This guide explains how to configure TrueNAS Scale to automatically bootstrap the infrastructure tier on every boot.

## Why Init Scripts Instead of SystemD?

TrueNAS Scale **wipes and rebuilds** the root filesystem during system upgrades. This means:
- ❌ SystemD services in `/etc/systemd/system/` are lost on upgrade
- ❌ Files in `/root/` are lost on upgrade
- ✅ Init/Shutdown Scripts configured via UI **survive upgrades**
- ✅ Files on persistent datasets (e.g., `/mnt/apps01/`) **survive upgrades**

## Setup Instructions

### 1. Ensure Repository is Cloned

The repository should already be cloned to a persistent dataset:

```bash
ls -la /mnt/apps01/repos/homelab/scripts/truenas-post-init.sh
```

If not present, clone it:

```bash
cd /mnt/apps01/repos
git clone https://github.com/cpritchett/homelab.git
```

### 2. Verify Script is Executable

```bash
chmod +x /mnt/apps01/repos/homelab/scripts/truenas-post-init.sh
chmod +x /mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh
```

### 3. Create Swarm Secrets (First Time Only)

Before the first bootstrap, create the required Swarm secrets:

```bash
# Using 1Password CLI (if available)
op read "op://homelab/Komodo - Barbary/Database" | docker secret create komodo_db_password -
op read "op://homelab/Komodo - Barbary/credential" | docker secret create komodo_passkey -

# Or use the helper script
/mnt/apps01/repos/homelab/scripts/create-swarm-secrets.sh
```

Verify secrets exist:

```bash
docker secret ls
# Should show: op_connect_token, CLOUDFLARE_API_TOKEN, komodo_db_password, komodo_passkey
```

### 4. Configure Init Script in TrueNAS UI

1. Navigate to: **System Settings → Advanced → Init/Shutdown Scripts**

2. Click **Add** and configure:
   ```
   Description: Homelab Infrastructure Bootstrap
   Type: Command
   When: Post Init
   Command: /mnt/apps01/repos/homelab/scripts/truenas-post-init.sh
   Timeout: 600
   Enabled: ✓
   ```

3. **Save**

### 5. Test the Init Script

You can test the script manually without rebooting:

```bash
sudo /mnt/apps01/repos/homelab/scripts/truenas-post-init.sh
```

Check the logs:

```bash
tail -f /var/log/homelab-bootstrap.log
```

### 6. Verify After Reboot

After a system reboot, verify all services started automatically:

```bash
docker service ls
docker stack ls
```

You should see all infrastructure services running:
- op-connect (2 services)
- komodo (3 services)
- caddy (2 services)

## Script Behavior

### What the Bootstrap Script Does:

1. ✅ Verifies Docker is running
2. ✅ Initializes Docker Swarm (if not already active)
3. ✅ Creates overlay networks (proxy_network, op-connect_op-connect)
4. ✅ Verifies Swarm secrets exist (exits if missing)
5. ✅ Creates application data directories
6. ✅ Sets directory permissions
7. ✅ Deploys infrastructure stacks in order:
   - op-connect
   - komodo
   - caddy

### Idempotency:

The script is **fully idempotent** and safe to run multiple times:
- Networks: Only creates if they don't exist
- Secrets: Only checks existence (doesn't modify)
- Directories: Creates missing directories, preserves existing
- Stacks: Updates if already deployed, creates if missing

### What Happens on Upgrade:

When you upgrade TrueNAS Scale:

1. ✅ Repository at `/mnt/apps01/repos/homelab/` **persists**
2. ✅ Init script configuration in UI **persists**
3. ✅ Docker Swarm state **persists**
4. ✅ Swarm secrets **persist**
5. ✅ Application data in `/mnt/apps01/appdata/` **persists**
6. ✅ On first boot after upgrade, init script runs automatically
7. ✅ All infrastructure services start automatically

## Troubleshooting

### Init Script Didn't Run

Check TrueNAS logs:

```bash
grep -i "Init/Shutdown" /var/log/middlewared.log
```

Verify script is configured:

```bash
midclt call initshutdownscript.query
```

### Bootstrap Failed

Check bootstrap logs:

```bash
tail -100 /var/log/homelab-bootstrap.log
```

Common issues:
- **Swarm secrets missing**: Create them with `create-swarm-secrets.sh`
- **Docker not ready**: Init script waits 10s, may need longer
- **Network issues**: Check DNS and external connectivity

### Services Not Starting

Verify Swarm is active:

```bash
docker info | grep Swarm
```

Check service logs:

```bash
docker service logs op-connect_op-connect-api
docker service logs komodo_core
docker service logs caddy_caddy
```

## Validation

Run the validation script to verify everything is healthy:

```bash
/mnt/apps01/repos/homelab/scripts/validate-phase1.sh
```

This checks:
- Docker Swarm status
- Networks and secrets
- All services running
- Service health checks
- External accessibility
- TLS certificates

## Manual Bootstrap

If you need to manually run the bootstrap (without reboot):

```bash
# Full bootstrap
sudo /mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh

# Or individual stacks
sudo docker stack deploy -c /mnt/apps01/repos/homelab/stacks/infrastructure/op-connect-compose.yaml op-connect
sudo docker stack deploy -c /mnt/apps01/repos/homelab/stacks/infrastructure/komodo-compose.yaml komodo
sudo docker stack deploy -c /mnt/apps01/repos/homelab/stacks/infrastructure/caddy-compose.yaml caddy
```

## Updating the Repository

To update the infrastructure configuration:

```bash
cd /mnt/apps01/repos/homelab
git pull origin main

# Re-deploy affected stacks
docker stack deploy -c stacks/infrastructure/komodo-compose.yaml komodo
```

Changes to the init script itself take effect on next reboot or manual run.

## Related Documentation

- **Bootstrap Script**: `scripts/truenas-init-bootstrap.sh`
- **Validation Script**: `scripts/validate-phase1.sh`
- **Phase 1 Runbook**: `docs/deployment/PHASE1_DEPLOYMENT_RUNBOOK.md`
- **Permissions Reference**: `docs/deployment/PERMISSIONS_REFERENCE.md`
