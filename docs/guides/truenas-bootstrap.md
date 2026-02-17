# TrueNAS Bootstrap Guide

This guide covers the complete bootstrap of the homelab infrastructure tier on TrueNAS Scale — from initial storage setup through a fully operational, reboot-resilient deployment.

## Overview

The bootstrap system ensures that the core infrastructure services (1Password Connect, Komodo, and Caddy) are automatically deployed when TrueNAS boots up.

```
TrueNAS Boot
    ↓
Init Script (survives TrueNAS upgrades)
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

Before starting, ensure you have:

- TrueNAS Scale 24.04 (Dragonfish) or later installed
- Docker service enabled (Applications → Settings → Advanced → Enable Docker)
- SSH access with root privileges
- 1Password CLI installed and authenticated on your workstation
- Cloudflare account with hypyr.space domain
- Minimum 16GB RAM (32GB+ recommended), 4 CPU cores (8+ recommended)

## Pre-Flight Checklist

### Hardware & OS

- [ ] TrueNAS Scale installed and accessible
- [ ] Network interface configured with static IP
- [ ] System hostname set correctly (`barbary.hypyr.space`)
- [ ] SSH access working
- [ ] Docker service running: `systemctl status docker`

### 1Password Credentials (on workstation)

- [ ] 1Password CLI authenticated: `op account list`
- [ ] Connect server credentials generated:
  ```bash
  mkdir -p ~/homelab-secrets && cd ~/homelab-secrets
  op connect server create barbary --vaults homelab
  # Creates: 1password-credentials.json + token file
  mv op_barbary.token connect-token
  ```
- [ ] Homelab vault has `Komodo - Barbary` item with `Database` and `credential` fields

### Cloudflare API Token

- [ ] API token created at https://dash.cloudflare.com/profile/api-tokens
  - Template: Edit zone DNS
  - Zone: hypyr.space
- [ ] Token saved: `echo "YOUR_TOKEN" > ~/homelab-secrets/cloudflare-api-token`

### DNS Records

- [ ] `barbary.hypyr.space` → A record → TrueNAS IP
- [ ] `*.in.hypyr.space` → CNAME → `barbary.hypyr.space`
- [ ] DNS propagation verified: `dig komodo.in.hypyr.space +short`

## Step-by-Step Deployment

### Step 1: Create ZFS Datasets

```bash
# On TrueNAS shell
zfs create apps01/appdata
zfs create apps01/secrets
zfs create apps01/repos
zfs create data01/data

# Set properties
zfs set acltype=posixacl apps01/appdata
zfs set acltype=posixacl apps01/secrets
zfs set acltype=posixacl apps01/repos
zfs set acltype=posixacl data01/data

zfs set aclinherit=passthrough apps01/appdata
zfs set aclinherit=passthrough apps01/secrets
zfs set aclinherit=passthrough data01/data

zfs set casesensitivity=sensitive apps01/appdata
zfs set casesensitivity=sensitive apps01/repos
zfs set casesensitivity=sensitive data01/data

# Performance tuning
zfs set atime=off apps01/appdata
zfs set atime=off data01/data
zfs set compression=lz4 apps01/appdata
zfs set compression=lz4 apps01/secrets

# Verify
zfs get acltype,aclinherit,casesensitivity,compression apps01/appdata
```

### Step 2: Create Service Users and Groups

```bash
# Groups
groupadd -g 568 komodo 2>/dev/null || echo "Group 'komodo' exists"
groupadd -g 999 opuser 2>/dev/null || echo "Group 'opuser' exists"
groupadd -g 1701 caddy 2>/dev/null || echo "Group 'caddy' exists"
groupadd -g 1702 caddyshared 2>/dev/null || echo "Group 'caddyshared' exists"

# Users
useradd -u 568 -g 568 -m -s /bin/bash komodo 2>/dev/null || echo "User 'komodo' exists"
useradd -u 999 -g 999 -m -s /bin/bash opuser 2>/dev/null || echo "User 'opuser' exists"
useradd -u 1701 -g 1701 -m -s /bin/bash caddy 2>/dev/null || echo "User 'caddy' exists"

# Add to docker group
usermod -aG docker komodo
usermod -aG docker opuser
usermod -aG docker caddy

# Verify
id komodo && id opuser && id caddy
```

### Step 3: Create Directory Structure

```bash
mkdir -p /mnt/apps01/appdata/{op-connect,komodo,proxy}
mkdir -p /mnt/apps01/appdata/komodo/{mongodb,sync,backups,secrets,periphery}
mkdir -p /mnt/apps01/appdata/proxy/{caddy-data,caddy-config,caddy-secrets}
mkdir -p /mnt/apps01/secrets/{op,cloudflare}

# Set ownership
chown -R 999:999 /mnt/apps01/appdata/op-connect
chown -R 568:568 /mnt/apps01/appdata/komodo
chown -R 1701:1702 /mnt/apps01/appdata/proxy
chown -R root:root /mnt/apps01/secrets

# Set permissions
chmod 755 /mnt/apps01/appdata
chmod 750 /mnt/apps01/secrets
chmod 700 /mnt/apps01/appdata/komodo/mongodb
chmod 770 /mnt/apps01/appdata/komodo/secrets
chmod 700 /mnt/apps01/appdata/proxy/caddy-data
chmod 700 /mnt/apps01/secrets/op
chmod 700 /mnt/apps01/secrets/cloudflare
```

For full UID/GID mappings and ACL details, see [Permissions Reference](../reference/permissions.md).

### Step 4: Clone Repository

```bash
cd /mnt/apps01/repos
git clone https://github.com/YOUR_USERNAME/homelab.git
chown -R root:docker /mnt/apps01/repos/homelab
chmod -R 755 /mnt/apps01/repos/homelab
chmod +x /mnt/apps01/repos/homelab/scripts/*.sh
```

### Step 5: Copy Secrets from Workstation

**On your workstation:**

```bash
scp ~/homelab-secrets/1password-credentials.json root@barbary:/mnt/apps01/secrets/op/
scp ~/homelab-secrets/connect-token root@barbary:/mnt/apps01/secrets/op/
scp ~/homelab-secrets/cloudflare-api-token root@barbary:/mnt/apps01/secrets/cloudflare/api-token
```

**On TrueNAS — set permissions and ACLs:**

```bash
# File permissions
chown root:root /mnt/apps01/secrets/op/* /mnt/apps01/secrets/cloudflare/*
chmod 600 /mnt/apps01/secrets/op/1password-credentials.json
chmod 600 /mnt/apps01/secrets/op/connect-token
chmod 600 /mnt/apps01/secrets/cloudflare/api-token

# Directory ACLs for traversal
chmod 750 /mnt/apps01/secrets/op
chmod 750 /mnt/apps01/secrets/cloudflare
setfacl -m u:999:r-x /mnt/apps01/secrets/op
setfacl -m u:568:r-x /mnt/apps01/secrets/op
setfacl -m u:1701:r-x /mnt/apps01/secrets/cloudflare

# File ACLs — op-connect reads credentials
setfacl -m u:999:r-- /mnt/apps01/secrets/op/1password-credentials.json
setfacl -m u:999:r-- /mnt/apps01/secrets/op/connect-token

# File ACLs — Komodo reads connect token
setfacl -m u:568:r-- /mnt/apps01/secrets/op/connect-token

# File ACLs — Caddy reads Cloudflare token
setfacl -m u:1701:r-- /mnt/apps01/secrets/cloudflare/api-token

# Verify
getfacl /mnt/apps01/secrets/op/1password-credentials.json
getfacl /mnt/apps01/secrets/op/connect-token
getfacl /mnt/apps01/secrets/cloudflare/api-token
```

### Step 6: Test Permissions

```bash
# Service account read tests
sudo -u '#999' cat /mnt/apps01/secrets/op/1password-credentials.json >/dev/null && echo "✓ opuser can read credentials" || echo "✗ FAIL"
sudo -u '#568' cat /mnt/apps01/secrets/op/connect-token >/dev/null && echo "✓ komodo can read token" || echo "✗ FAIL"
sudo -u '#1701' cat /mnt/apps01/secrets/cloudflare/api-token >/dev/null && echo "✓ caddy can read cloudflare token" || echo "✗ FAIL"

# Write tests
sudo -u '#568' touch /mnt/apps01/appdata/komodo/mongodb/.test && \
sudo -u '#568' rm /mnt/apps01/appdata/komodo/mongodb/.test && echo "✓ komodo can write to mongodb" || echo "✗ FAIL"

sudo -u '#1701' touch /mnt/apps01/appdata/proxy/caddy-data/.test && \
sudo -u '#1701' rm /mnt/apps01/appdata/proxy/caddy-data/.test && echo "✓ caddy can write to caddy-data" || echo "✗ FAIL"

# Docker socket
sudo -u komodo docker ps >/dev/null 2>&1 && echo "✓ komodo can access Docker" || echo "✗ FAIL"
```

**STOP if any test fails.** Review [Permissions Reference](../reference/permissions.md) before proceeding.

### Step 7: Create Swarm Secrets (First Time Only)

```bash
# Using 1Password CLI (if available on TrueNAS)
op read "op://homelab/Komodo - Barbary/Database" | docker secret create komodo_db_password -
op read "op://homelab/Komodo - Barbary/credential" | docker secret create komodo_passkey -

# Or use the helper script
/mnt/apps01/repos/homelab/scripts/create-swarm-secrets.sh

# Verify
docker secret ls
# Should show: op_connect_token, CLOUDFLARE_API_TOKEN, komodo_db_password, komodo_passkey
```

### Step 8: Run Bootstrap Script

```bash
cd /mnt/apps01/repos/homelab
./scripts/truenas-init-bootstrap.sh
```

The script is **fully idempotent** — safe to run multiple times. It will:
1. Initialize Docker Swarm (if not already active)
2. Create overlay networks (`proxy_network`, `op-connect_op-connect`)
3. Verify Swarm secrets exist
4. Deploy infrastructure stacks in order: op-connect → komodo → caddy

Monitor in a second terminal:
```bash
watch -n 2 'docker stack ls && echo "" && docker service ls'
```

### Step 9: Verify Infrastructure Services

```bash
# Swarm
docker info | grep "Swarm: active"
docker node ls

# Networks and secrets
docker network ls | grep -E 'proxy_network|op-connect'
docker secret ls

# Stacks and services
docker stack ls
docker service ls

# Health checks
docker exec $(docker ps -q -f name=op-connect-api) curl -s http://localhost:8080/health | jq .
docker exec $(docker ps -q -f name=komodo_mongo) mongosh --quiet --eval "db.adminCommand('ping')"
curl -k -I https://komodo.in.hypyr.space
```

### Step 10: Access Komodo and Complete Setup

1. Navigate to https://komodo.in.hypyr.space
2. Create admin user on first visit
3. Add Git integration → repository URL → branch `main`
4. Verify Periphery server (`barbary-periphery`) is connected

## Init Script Configuration

TrueNAS Scale **wipes the root filesystem during upgrades**, so:
- SystemD services in `/etc/systemd/system/` are lost on upgrade
- Init/Shutdown Scripts configured via UI **survive upgrades**
- Files on persistent datasets (`/mnt/apps01/`) **survive upgrades**

### Configure via TrueNAS UI (Recommended)

1. Navigate to **System Settings → Advanced → Init/Shutdown Scripts**
2. Click **Add**:
   - **Description:** Homelab Infrastructure Bootstrap
   - **Type:** Command
   - **When:** Post Init
   - **Command:** `/mnt/apps01/repos/homelab/scripts/truenas-post-init.sh`
   - **Timeout:** 600
   - **Enabled:** ✓
3. **Save**

### Alternative: SystemD Service

If you prefer systemd (re-create after each TrueNAS upgrade):

```bash
cat > /etc/systemd/system/homelab-bootstrap.service <<'EOF'
[Unit]
Description=Homelab Infrastructure Bootstrap
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh
StandardOutput=journal
StandardError=journal
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable homelab-bootstrap.service
```

### What Persists Across Upgrades

| Item | Survives? |
|------|-----------|
| Repository at `/mnt/apps01/repos/homelab/` | ✅ |
| Init script configuration in TrueNAS UI | ✅ |
| Docker Swarm state | ✅ |
| Swarm secrets | ✅ |
| Application data in `/mnt/apps01/appdata/` | ✅ |
| SystemD services in `/etc/systemd/system/` | ❌ |

## Post-Deployment Validation

### Core Infrastructure

- [ ] Docker Swarm active: `docker info | grep "Swarm: active"`
- [ ] Networks: `proxy_network` and `op-connect_op-connect` exist
- [ ] Secrets: `op_connect_token` and `CLOUDFLARE_API_TOKEN` exist
- [ ] Stack `op-connect` running (2 services healthy)
- [ ] Stack `komodo` running (3 services healthy)
- [ ] Stack `caddy` running

### External Access

- [ ] Komodo UI accessible at https://komodo.in.hypyr.space
- [ ] TLS certificate issued by Let's Encrypt
- [ ] No certificate errors in browser

### Persistence

- [ ] Data directories populated: `/mnt/apps01/appdata/komodo/mongodb/` is non-empty
- [ ] Service accounts can write to their directories

### Reboot Resilience

- [ ] Reboot TrueNAS: `reboot`
- [ ] After 2-5 minutes, verify all services auto-started: `docker stack ls && docker service ls`

### Backup Snapshot

```bash
zfs snapshot apps01/appdata@phase1-complete
zfs snapshot apps01/secrets@phase1-complete
zfs snapshot apps01/repos@phase1-complete
```

## Troubleshooting

### Bootstrap Script Fails

```bash
tail -100 /var/log/homelab-bootstrap.log
```

| Issue | Fix |
|-------|-----|
| "Repository path not found" | Clone repo to `/mnt/apps01/repos/homelab` |
| "1Password Connect token not found" | Generate and copy credentials (see Step 5) |
| "Docker is not running" | Enable Docker in TrueNAS Applications settings |
| Stack deployment fails | Check compose syntax and service logs |

### Services Not Starting

```bash
docker service ls
docker service ps SERVICE_NAME --no-trunc
docker service logs SERVICE_NAME --tail 100
```

| Issue | Fix |
|-------|-----|
| op-connect: credentials error | Verify JSON is valid: `jq . /mnt/apps01/secrets/op/1password-credentials.json` |
| MongoDB: data directory not writable | `chown -R 568:568 /mnt/apps01/appdata/komodo/mongodb && chmod 700 /mnt/apps01/appdata/komodo/mongodb` |
| Caddy: certificate errors | Check Cloudflare token validity and DNS propagation |
| Secrets injection: permission denied | Verify ACLs on secret files and execute permission on parent dirs |
| Docker socket: access denied | `chmod 660 /var/run/docker.sock && chown root:docker /var/run/docker.sock` |

### Init Script Didn't Run

```bash
grep -i "Init/Shutdown" /var/log/middlewared.log
midclt call initshutdownscript.query
```

## Next Steps

With Phase 1 complete, proceed to:
- [Platform Deployment Guide](platform-deployment.md) — Authentik, monitoring, backups
- [Authentik Deployment](authentik-deployment.md) — SSO stack details

## References

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Komodo Documentation](https://github.com/moghtech/komodo)
- [1Password Connect](https://developer.1password.com/docs/connect/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
