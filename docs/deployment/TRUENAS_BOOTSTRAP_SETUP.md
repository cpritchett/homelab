# TrueNAS Scale Bootstrap Setup Guide

This guide covers the installation and configuration of the automatic bootstrap system for the homelab infrastructure tier on TrueNAS Scale.

## Overview

The bootstrap system ensures that the core infrastructure services (1Password Connect, Komodo, and Caddy) are automatically deployed when TrueNAS boots up. This is critical for a self-healing infrastructure that can survive reboots.

## Architecture

```
TrueNAS Boot
    ↓
systemd: homelab-bootstrap.service
    ↓
/mnt/apps01/scripts/truenas-init-bootstrap.sh
    ↓
Docker Swarm Initialization
    ↓
Infrastructure Tier Deployment
    ├── op-connect (secrets management)
    ├── komodo (orchestration UI)
    └── caddy (reverse proxy/TLS)
```

## Prerequisites

Before setting up the bootstrap system, ensure the following are in place:

### 1. TrueNAS Scale Installed
- TrueNAS Scale 24.04 (Dragonfish) or later
- Docker service enabled (Applications → Settings → Advanced → Enable Docker)

### 2. Storage Structure

Create the required datasets on your pool (assuming pool name `apps01` and `data01`):

```bash
# On TrueNAS shell
zfs create apps01/appdata
zfs create apps01/secrets
zfs create apps01/repos
zfs create data01/data
```

### 3. Repository Cloned

Clone the homelab repository to the designated location:

```bash
cd /mnt/apps01/repos
git clone https://github.com/YOUR_USERNAME/homelab.git
```

### 4. Secrets Prepared

Generate and save the required secrets:

#### 1Password Connect Credentials

```bash
# On your workstation with 1Password CLI authenticated
mkdir -p /tmp/op-credentials

# Generate 1Password Connect server credentials
op connect server create barbary --vaults homelab --output /tmp/op-credentials/

# This creates:
#   - 1password-credentials.json (server credentials)
#   - token (connect token)
```

Copy these files to TrueNAS:

```bash
# From your workstation
scp /tmp/op-credentials/1password-credentials.json root@barbary:/mnt/apps01/secrets/op/
scp /tmp/op-credentials/token root@barbary:/mnt/apps01/secrets/op/connect-token

# On TrueNAS, set proper permissions
chmod 600 /mnt/apps01/secrets/op/*
```

#### Cloudflare API Token

Create a Cloudflare API token with DNS edit permissions:

1. Log in to Cloudflare dashboard
2. Go to Profile → API Tokens
3. Create Token → Edit zone DNS template
4. Zone Resources: Include → Specific zone → hypyr.space
5. Create Token

Save the token to TrueNAS:

```bash
# On TrueNAS
mkdir -p /mnt/apps01/secrets/cloudflare
echo "YOUR_CLOUDFLARE_TOKEN" > /mnt/apps01/secrets/cloudflare/api-token
chmod 600 /mnt/apps01/secrets/cloudflare/api-token
```

### 5. DNS Configuration

Create DNS records pointing to your TrueNAS IP:

```
op-connect.in.hypyr.space   → CNAME → barbary.hypyr.space
komodo.in.hypyr.space       → CNAME → barbary.hypyr.space
barbary.hypyr.space         → A     → 10.0.0.X (your TrueNAS IP)
*.in.hypyr.space            → CNAME → barbary.hypyr.space
```

## Installation

### Method 1: SystemD Service (Recommended)

Create the systemd service file on TrueNAS:

```bash
# On TrueNAS shell
cat > /etc/systemd/system/homelab-bootstrap.service <<'EOF'
[Unit]
Description=Homelab Infrastructure Bootstrap
Documentation=https://github.com/YOUR_USERNAME/homelab
After=docker.service
Requires=docker.service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/mnt/apps01/scripts/truenas-init-bootstrap.sh
StandardOutput=journal
StandardError=journal
TimeoutStartSec=600
Restart=on-failure
RestartSec=30

# Environment variables (optional overrides)
#Environment="REPO_PATH=/mnt/apps01/repos/homelab"
#Environment="SECRETS_PATH=/mnt/apps01/secrets"
#Environment="APPDATA_PATH=/mnt/apps01/appdata"

[Install]
WantedBy=multi-user.target
EOF
```

Enable and start the service:

```bash
# Reload systemd to pick up new service
systemctl daemon-reload

# Enable service to run on boot
systemctl enable homelab-bootstrap.service

# Start service now (first-time deployment)
systemctl start homelab-bootstrap.service

# Check status
systemctl status homelab-bootstrap.service

# View logs
journalctl -u homelab-bootstrap.service -f
```

### Method 2: TrueNAS Init/Shutdown Scripts (Alternative)

If systemd persistence is a concern on TrueNAS Scale, use the built-in Init/Shutdown Scripts feature:

1. Navigate to **System Settings** → **Advanced** → **Init/Shutdown Scripts**
2. Click **Add**
3. Configure:
   - **Description:** Homelab Infrastructure Bootstrap
   - **Type:** Command
   - **When:** Post Init
   - **Command:** `/mnt/apps01/scripts/truenas-init-bootstrap.sh`
   - **Enabled:** ✓
4. Click **Save**

Test the script:

```bash
# Run manually to test
/mnt/apps01/scripts/truenas-init-bootstrap.sh

# Check logs
tail -f /var/log/homelab-bootstrap.log
```

## Verification

After bootstrap completes, verify the infrastructure tier:

### 1. Check Docker Swarm

```bash
docker info | grep Swarm
# Should show: Swarm: active

docker node ls
# Should show: barbary as the manager node
```

### 2. Check Networks

```bash
docker network ls | grep -E 'proxy_network|op-connect'
# Should show both overlay networks
```

### 3. Check Secrets

```bash
docker secret ls
# Should show:
#   - op_connect_token
#   - CLOUDFLARE_API_TOKEN
```

### 4. Check Stacks

```bash
docker stack ls
# Should show:
#   - op-connect
#   - komodo
#   - caddy

docker stack ps op-connect
docker stack ps komodo
docker stack ps caddy
# All services should be in "Running" state
```

### 5. Check Service Health

```bash
# 1Password Connect API
curl http://op-connect-api:8080/health
# Should return: {"name":"1Password Connect API","version":"..."}

# Komodo UI (requires TLS)
curl -k https://komodo.in.hypyr.space
# Should return HTML (Komodo login page)

# Caddy proxy
docker service logs caddy_caddy --tail 50
# Should show successful certificate issuance
```

### 6. Access Services

- **Komodo:** https://komodo.in.hypyr.space
  - First-time setup: Create admin user
  - Configure Git sync to repository
  - Add Periphery server (auto-discovered)

- **1Password Connect:** http://op-connect-api:8080
  - Not directly exposed (internal service)
  - Verify via stack service logs

## Troubleshooting

### Bootstrap Script Fails

Check the log file:

```bash
tail -100 /var/log/homelab-bootstrap.log
```

Common issues:

1. **"Repository path not found"**
   - Solution: Clone the homelab repository to `/mnt/apps01/repos/homelab`

2. **"1Password Connect token not found"**
   - Solution: Generate and copy credentials as described in Prerequisites

3. **"Docker is not running"**
   - Solution: Enable Docker in TrueNAS Applications settings
   - Check: `systemctl status docker`

4. **Stack deployment fails**
   - Check compose file syntax: `docker stack deploy --dry-run -c FILE.yaml STACK_NAME`
   - View service errors: `docker service ls` then `docker service logs SERVICE_NAME`

### Services Not Starting

Check service logs:

```bash
# List services
docker service ls

# Check specific service
docker service ps SERVICE_NAME --no-trunc

# View logs
docker service logs SERVICE_NAME --tail 100 -f
```

Common issues:

1. **op-connect fails to start**
   - Check credentials file exists and is readable
   - Verify file contents are valid JSON
   - Check: `docker service logs op-connect_op-connect-api`

2. **komodo fails - MongoDB errors**
   - MongoDB may need time to initialize (first boot takes 60+ seconds)
   - Check MongoDB logs: `docker service logs komodo_mongo`
   - Verify directory permissions: `ls -la /mnt/apps01/appdata/komodo/mongodb`

3. **caddy fails - certificate errors**
   - Check Cloudflare API token is valid
   - Verify DNS propagation: `dig komodo.in.hypyr.space`
   - Check Caddy logs: `docker service logs caddy_caddy`

### Network Issues

Check network connectivity:

```bash
# Verify networks exist
docker network inspect proxy_network
docker network inspect op-connect_op-connect

# Check service network attachments
docker service inspect SERVICE_NAME --format '{{json .Spec.TaskTemplate.Networks}}'
```

### Permission Issues

Fix directory permissions:

```bash
# Caddy (UID/GID 1701:1702)
chown -R 1701:1702 /mnt/apps01/appdata/proxy

# Komodo/MongoDB (UID/GID 568:568)
chown -R 568:568 /mnt/apps01/appdata/komodo

# Verify
ls -la /mnt/apps01/appdata/
```

## Maintenance

### Updating Stacks

To update a stack after repository changes:

```bash
# Pull latest changes
cd /mnt/apps01/repos/homelab
git pull

# Redeploy stack
docker stack deploy -c stacks/infrastructure/STACK-compose.yaml STACK_NAME

# Watch rollout
watch docker service ls
```

### Backup Critical Data

Backup these paths regularly:

- `/mnt/apps01/secrets/` - All secrets (store in 1Password vault)
- `/mnt/apps01/appdata/komodo/mongodb/` - Komodo configuration database
- `/mnt/apps01/appdata/proxy/caddy-data/` - TLS certificates

### Viewing Bootstrap Logs

```bash
# SystemD journal
journalctl -u homelab-bootstrap.service -n 100

# Log file
tail -100 /var/log/homelab-bootstrap.log

# Live monitoring
journalctl -u homelab-bootstrap.service -f
```

### Disabling Bootstrap

If you need to prevent automatic deployment:

```bash
# Disable systemd service
systemctl disable homelab-bootstrap.service
systemctl stop homelab-bootstrap.service

# Or remove TrueNAS Init Script
# Navigate to System Settings → Advanced → Init/Shutdown Scripts
# Uncheck "Enabled" or delete the script
```

### Manual Cleanup

To remove all infrastructure tier services:

```bash
# Remove stacks (in reverse order)
docker stack rm caddy
docker stack rm komodo
docker stack rm op-connect

# Wait for cleanup
sleep 30

# Verify removal
docker stack ls
docker service ls
```

## Validation Checklist

Before considering Phase 1 complete, verify:

- [ ] TrueNAS Scale is running and accessible
- [ ] Storage pools and datasets are created (`apps01`, `data01`)
- [ ] Repository is cloned to `/mnt/apps01/repos/homelab`
- [ ] 1Password credentials are in `/mnt/apps01/secrets/op/`
- [ ] Cloudflare API token is in `/mnt/apps01/secrets/cloudflare/`
- [ ] DNS records are configured and resolving
- [ ] Bootstrap script is executable
- [ ] SystemD service is installed and enabled (or Init Script configured)
- [ ] Bootstrap script runs successfully (check logs)
- [ ] Docker Swarm is initialized
- [ ] Networks `proxy_network` and `op-connect_op-connect` exist
- [ ] Secrets `op_connect_token` and `CLOUDFLARE_API_TOKEN` exist
- [ ] Stack `op-connect` is running (2 services healthy)
- [ ] Stack `komodo` is running (3 services healthy)
- [ ] Stack `caddy` is running (services healthy)
- [ ] Komodo UI is accessible at https://komodo.in.hypyr.space
- [ ] TLS certificates are being issued by Caddy
- [ ] op-connect API responds to health checks

## Next Steps

With Phase 1 complete, proceed to:

1. **Configure Komodo:**
   - Create admin user
   - Connect to Git repository
   - Configure Periphery server

2. **Phase 2: Platform Services**
   - Deploy monitoring stack (Grafana, Loki, Prometheus)
   - Deploy Wazuh SIEM
   - Configure dashboards and alerts

3. **Phase 3+: Application Migration**
   - Begin migrating applications from Kubernetes to Docker Swarm
   - Follow the migration plan in the main deployment guide

## References

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Komodo Documentation](https://github.com/moghtech/komodo)
- [1Password Connect](https://developer.1password.com/docs/connect/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
