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

# Set dataset properties for performance and compatibility
zfs set acltype=posixacl apps01/appdata
zfs set acltype=posixacl apps01/secrets
zfs set acltype=posixacl apps01/repos
zfs set acltype=posixacl data01/data

# Enable ACL inheritance
zfs set aclinherit=passthrough apps01/appdata
zfs set aclinherit=passthrough apps01/secrets
zfs set aclinherit=passthrough data01/data

# Set case sensitivity (important for Docker)
zfs set casesensitivity=sensitive apps01/appdata
zfs set casesensitivity=sensitive apps01/repos
zfs set casesensitivity=sensitive data01/data

# Verify
zfs get acltype,aclinherit,casesensitivity apps01/appdata
```

### 3. Permissions and ACL Configuration

Docker containers run with specific UIDs/GIDs. TrueNAS needs proper permissions and ACLs configured:

#### Create Service Users/Groups

```bash
# Create groups (if they don't exist)
groupadd -g 568 komodo 2>/dev/null || true
groupadd -g 999 opuser 2>/dev/null || true
groupadd -g 1701 caddy 2>/dev/null || true
groupadd -g 1702 caddyshared 2>/dev/null || true

# Create users (if they don't exist)
useradd -u 568 -g 568 -m -s /bin/bash komodo 2>/dev/null || true
useradd -u 999 -g 999 -m -s /bin/bash opuser 2>/dev/null || true
useradd -u 1701 -g 1701 -m -s /bin/bash caddy 2>/dev/null || true

# Add users to docker group for socket access
usermod -aG docker komodo
usermod -aG docker opuser
usermod -aG docker caddy
```

#### Set Base Permissions

```bash
# Create directory structure with proper ownership
mkdir -p /mnt/apps01/appdata/{op-connect,komodo,proxy}
mkdir -p /mnt/apps01/appdata/komodo/{mongodb,sync,backups,secrets,periphery}
mkdir -p /mnt/apps01/appdata/proxy/{caddy-data,caddy-config,caddy-secrets}
mkdir -p /mnt/apps01/secrets/{op,cloudflare}
mkdir -p /mnt/apps01/repos

# Set ownership
chown -R 999:999 /mnt/apps01/appdata/op-connect
chown -R 568:568 /mnt/apps01/appdata/komodo
chown -R 1701:1702 /mnt/apps01/appdata/proxy
chown -R root:root /mnt/apps01/secrets
chown -R root:root /mnt/apps01/repos

# Set base permissions
chmod 755 /mnt/apps01/appdata
chmod 750 /mnt/apps01/secrets
chmod 755 /mnt/apps01/repos

# Secrets should be read-only for service accounts
chmod 700 /mnt/apps01/secrets/op
chmod 700 /mnt/apps01/secrets/cloudflare
```

#### Configure ACLs for Shared Access

Some directories need to be accessed by multiple services (e.g., secrets directory):

```bash
# Allow op-connect (999) to read its own credentials
setfacl -m u:999:r-x /mnt/apps01/secrets/op
setfacl -m u:999:r-- /mnt/apps01/secrets/op/1password-credentials.json
setfacl -m u:999:r-- /mnt/apps01/secrets/op/connect-token

# Allow caddy (1701) to read Cloudflare token
setfacl -m u:1701:r-x /mnt/apps01/secrets/cloudflare
setfacl -m u:1701:r-- /mnt/apps01/secrets/cloudflare/api-token

# Allow komodo (568) to read secrets for injection
setfacl -m u:568:r-x /mnt/apps01/secrets/op
setfacl -m u:568:r-- /mnt/apps01/secrets/op/connect-token

# Set default ACLs for new files in appdata (inherit parent permissions)
setfacl -d -m u::rwx /mnt/apps01/appdata/komodo
setfacl -d -m g::r-x /mnt/apps01/appdata/komodo
setfacl -d -m o::--- /mnt/apps01/appdata/komodo

# Verify ACLs
getfacl /mnt/apps01/secrets/op
getfacl /mnt/apps01/appdata/komodo
```

#### MongoDB Data Directory Permissions

MongoDB requires specific permissions on its data directory:

```bash
# MongoDB data directory must be owned by mongodb user inside container (568)
chown -R 568:568 /mnt/apps01/appdata/komodo/mongodb
chmod 700 /mnt/apps01/appdata/komodo/mongodb

# Secrets directory for environment injection
chown 568:568 /mnt/apps01/appdata/komodo/secrets
chmod 770 /mnt/apps01/appdata/komodo/secrets

# Verify MongoDB can write
sudo -u komodo touch /mnt/apps01/appdata/komodo/mongodb/test
sudo -u komodo rm /mnt/apps01/appdata/komodo/mongodb/test
```

#### Docker Socket Permissions

Ensure containers can access Docker socket:

```bash
# Docker socket should be accessible by docker group
chmod 660 /var/run/docker.sock
chown root:docker /var/run/docker.sock

# Verify service users can access socket
sudo -u komodo docker ps >/dev/null 2>&1 && echo "✓ Komodo can access Docker" || echo "✗ Komodo CANNOT access Docker"
```

#### Verify Permissions Summary

```bash
# Create verification script
cat > /tmp/verify-permissions.sh <<'EOF'
#!/bin/bash
echo "=== Directory Ownership ==="
ls -la /mnt/apps01/ | grep -E 'appdata|secrets|repos'
echo ""
echo "=== Appdata Subdirectories ==="
ls -la /mnt/apps01/appdata/
echo ""
echo "=== Secrets Directories ==="
ls -la /mnt/apps01/secrets/
echo ""
echo "=== ACLs on Critical Paths ==="
getfacl /mnt/apps01/secrets/op 2>/dev/null | grep -E '^user:|^group:'
getfacl /mnt/apps01/appdata/komodo 2>/dev/null | grep -E '^user:|^group:'
echo ""
echo "=== Docker Socket ==="
ls -l /var/run/docker.sock
echo ""
echo "=== Service User Access Tests ==="
sudo -u opuser test -r /mnt/apps01/secrets/op/1password-credentials.json && echo "✓ opuser can read 1Password credentials" || echo "✗ opuser CANNOT read credentials"
sudo -u komodo test -r /mnt/apps01/secrets/op/connect-token && echo "✓ komodo can read op_connect_token" || echo "✗ komodo CANNOT read token"
sudo -u caddy test -r /mnt/apps01/secrets/cloudflare/api-token && echo "✓ caddy can read Cloudflare token" || echo "✗ caddy CANNOT read token"
sudo -u komodo docker ps >/dev/null 2>&1 && echo "✓ komodo can access Docker socket" || echo "✗ komodo CANNOT access Docker"
EOF

chmod +x /tmp/verify-permissions.sh
/tmp/verify-permissions.sh
```

### 4. Repository Cloned

Clone the homelab repository to the designated location:

```bash
cd /mnt/apps01/repos
git clone https://github.com/YOUR_USERNAME/homelab.git

# Set proper ownership
chown -R root:docker /mnt/apps01/repos/homelab
chmod -R 755 /mnt/apps01/repos/homelab
```

### 5. Secrets Prepared

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

# On TrueNAS, set proper permissions and ACLs
chmod 600 /mnt/apps01/secrets/op/1password-credentials.json
chmod 600 /mnt/apps01/secrets/op/connect-token
chown root:root /mnt/apps01/secrets/op/*

# Set ACLs to allow op-connect (UID 999) to read credentials
setfacl -m u:999:r-- /mnt/apps01/secrets/op/1password-credentials.json
setfacl -m u:999:r-- /mnt/apps01/secrets/op/connect-token

# Allow komodo (UID 568) to read token for secret injection
setfacl -m u:568:r-- /mnt/apps01/secrets/op/connect-token

# Verify ACLs
getfacl /mnt/apps01/secrets/op/1password-credentials.json
getfacl /mnt/apps01/secrets/op/connect-token
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
chown root:root /mnt/apps01/secrets/cloudflare/api-token

# Set ACL to allow caddy (UID 1701) to read token
setfacl -m u:1701:r-- /mnt/apps01/secrets/cloudflare/api-token

# Verify
getfacl /mnt/apps01/secrets/cloudflare/api-token
```

### 6. DNS Configuration

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

Fix directory permissions and ACLs:

```bash
# Caddy (UID/GID 1701:1702)
chown -R 1701:1702 /mnt/apps01/appdata/proxy
chmod 755 /mnt/apps01/appdata/proxy
chmod 700 /mnt/apps01/appdata/proxy/caddy-data

# Komodo/MongoDB (UID/GID 568:568)
chown -R 568:568 /mnt/apps01/appdata/komodo
chmod 755 /mnt/apps01/appdata/komodo
chmod 700 /mnt/apps01/appdata/komodo/mongodb

# op-connect (UID/GID 999:999)
chown -R 999:999 /mnt/apps01/appdata/op-connect
chmod 755 /mnt/apps01/appdata/op-connect

# Verify base permissions
ls -la /mnt/apps01/appdata/

# Verify ACLs on secrets
getfacl /mnt/apps01/secrets/op/1password-credentials.json
getfacl /mnt/apps01/secrets/op/connect-token
getfacl /mnt/apps01/secrets/cloudflare/api-token
```

**Common Permission Errors:**

1. **"Permission denied" when reading credentials**
   - Check file ownership: `ls -l /mnt/apps01/secrets/op/`
   - Check ACLs: `getfacl /mnt/apps01/secrets/op/1password-credentials.json`
   - Should show: `user:999:r--` for op-connect
   - Fix: Re-run ACL commands from Prerequisites section 3

2. **MongoDB fails with "Data directory not writable"**
   - Check ownership: `stat /mnt/apps01/appdata/komodo/mongodb`
   - Should be: `Uid: ( 568/ ...)`
   - Fix: `chown -R 568:568 /mnt/apps01/appdata/komodo/mongodb && chmod 700 /mnt/apps01/appdata/komodo/mongodb`

3. **"Could not open file for writing" errors**
   - Check parent directory permissions
   - Ensure no immutable flags: `lsattr /mnt/apps01/appdata/`
   - Check ZFS properties: `zfs get readonly,mountpoint apps01/appdata`

4. **Secrets injection fails with "Permission denied"**
   - Container needs both:
     - ACL read permission on secret file
     - Execute permission on parent directories
   - Fix:
     ```bash
     chmod 700 /mnt/apps01/secrets
     chmod 750 /mnt/apps01/secrets/op
     setfacl -m u:568:r-x /mnt/apps01/secrets/op
     setfacl -m u:568:r-- /mnt/apps01/secrets/op/connect-token
     ```

5. **Docker socket access denied**
   - Check socket permissions: `ls -l /var/run/docker.sock`
   - Should be: `srw-rw---- 1 root docker`
   - Fix:
     ```bash
     chmod 660 /var/run/docker.sock
     chown root:docker /var/run/docker.sock
     usermod -aG docker komodo
     ```

**Permission Testing Script:**

```bash
cat > /tmp/test-permissions.sh <<'EOF'
#!/bin/bash
echo "=== Testing Service Account Permissions ==="

# Test op-connect can read credentials
echo -n "op-connect (999) credentials: "
sudo -u '#999' test -r /mnt/apps01/secrets/op/1password-credentials.json && echo "✓ OK" || echo "✗ FAIL"

# Test komodo can read op token
echo -n "komodo (568) op token: "
sudo -u '#568' test -r /mnt/apps01/secrets/op/connect-token && echo "✓ OK" || echo "✗ FAIL"

# Test caddy can read cloudflare token
echo -n "caddy (1701) cloudflare token: "
sudo -u '#1701' test -r /mnt/apps01/secrets/cloudflare/api-token && echo "✓ OK" || echo "✗ FAIL"

# Test komodo can write to mongodb directory
echo -n "komodo (568) mongodb write: "
sudo -u '#568' touch /mnt/apps01/appdata/komodo/mongodb/.test 2>/dev/null && \
sudo -u '#568' rm /mnt/apps01/appdata/komodo/mongodb/.test 2>/dev/null && echo "✓ OK" || echo "✗ FAIL"

# Test caddy can write to caddy-data
echo -n "caddy (1701) caddy-data write: "
sudo -u '#1701' touch /mnt/apps01/appdata/proxy/caddy-data/.test 2>/dev/null && \
sudo -u '#1701' rm /mnt/apps01/appdata/proxy/caddy-data/.test 2>/dev/null && echo "✓ OK" || echo "✗ FAIL"

# Test docker socket access
echo -n "komodo (568) docker socket: "
sudo -u '#568' docker ps >/dev/null 2>&1 && echo "✓ OK" || echo "✗ FAIL"

echo ""
echo "If any tests show ✗ FAIL, review ACL and ownership settings"
EOF

chmod +x /tmp/test-permissions.sh
/tmp/test-permissions.sh
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
   - Follow: `docs/deployment/PHASE2_DEPLOYMENT_STEPS.md`
   - Execute queue from `specs/002-label-driven-swarm-infrastructure/spec.md`:
     - Task `#12`: Deploy Authentik SSO platform
     - Task `#14`: Build monitoring stack (Prometheus/Grafana/Loki)
     - Task `#15`: Set up Cloudflare Tunnel for Komodo GitHub webhooks

3. **Phase 3+: Application Migration**
   - Begin migrating applications from Kubernetes to Docker Swarm
   - Follow the migration plan in the main deployment guide

## References

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Komodo Documentation](https://github.com/moghtech/komodo)
- [1Password Connect](https://developer.1password.com/docs/connect/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
