# Phase 1 Deployment Runbook - TrueNAS Infrastructure Bootstrap

This runbook provides step-by-step commands to deploy the infrastructure tier on TrueNAS Scale.

**Estimated Time:** 45-60 minutes
**Prerequisites:** TrueNAS Scale installed, SSH access, root privileges

---

## Pre-Deployment Verification

**Location:** Your workstation (for 1Password credentials generation)

### Step 1: Generate 1Password Connect Credentials

```bash
# Ensure 1Password CLI is authenticated
op account list
op vault list

# Generate Connect server credentials
mkdir -p ~/homelab-secrets
cd ~/homelab-secrets

# Create the Connect server (replace 'barbary' with your hostname if different)
op connect server create barbary --vaults homelab

# This creates two files:
# - 1password-credentials.json (Connect server credentials)
# - op_barbary.token (Connect API token)

# Rename token file for consistency
mv op_barbary.token connect-token

# Verify files exist
ls -la
cat 1password-credentials.json | jq .
cat connect-token
```

**Expected Output:** JSON credentials file and token string

### Step 2: Verify 1Password Vault Structure

```bash
# Verify the homelab vault exists
op vault list | grep homelab

# Verify the Komodo item exists with correct structure
op item get "Komodo - Barbary" --vault homelab --fields label

# Should show fields:
# - Database (password for MongoDB)
# - credential (passkey for Komodo)

# Test secret references
op read "op://homelab/Komodo - Barbary/Database"
op read "op://homelab/Komodo - Barbary/credential"
```

**Expected Output:** Both commands return secret values (not shown in terminal for security)

### Step 3: Get Cloudflare API Token

```bash
# If you haven't created it yet:
# 1. Go to https://dash.cloudflare.com/profile/api-tokens
# 2. Create Token → Edit zone DNS template
# 3. Zone Resources: Include → Specific zone → hypyr.space
# 4. Create Token
# 5. Copy the token (shown only once)

# Save to file
echo "your_cloudflare_api_token_here" > ~/homelab-secrets/cloudflare-api-token
```

---

## TrueNAS Deployment

**Location:** TrueNAS Scale server (SSH as root)

### Step 4: Verify TrueNAS Prerequisites

```bash
# Verify Docker is running
systemctl status docker
docker --version

# Verify pools and datasets exist
zfs list | grep -E 'apps01|data01'

# Expected output:
# apps01              ...
# apps01/appdata      ...
# apps01/secrets      ...
# apps01/repos        ...
# data01/data         ...

# If datasets don't exist, create them:
zfs create apps01/appdata
zfs create apps01/secrets
zfs create apps01/repos
zfs create data01/data
```

### Step 5: Configure ZFS Properties

```bash
# Set ACL properties
zfs set acltype=posixacl apps01/appdata
zfs set acltype=posixacl apps01/secrets
zfs set acltype=posixacl apps01/repos
zfs set acltype=posixacl data01/data

# Set ACL inheritance
zfs set aclinherit=passthrough apps01/appdata
zfs set aclinherit=passthrough apps01/secrets
zfs set aclinherit=passthrough data01/data

# Set case sensitivity
zfs set casesensitivity=sensitive apps01/appdata
zfs set casesensitivity=sensitive apps01/repos
zfs set casesensitivity=sensitive data01/data

# Disable access time updates (performance)
zfs set atime=off apps01/appdata
zfs set atime=off data01/data

# Enable compression
zfs set compression=lz4 apps01/appdata
zfs set compression=lz4 apps01/secrets

# Verify
zfs get acltype,aclinherit,casesensitivity,compression apps01/appdata
```

**Expected Output:** All properties set correctly

### Step 6: Create Service Users and Groups

```bash
# Create groups
groupadd -g 568 komodo 2>/dev/null || echo "Group 'komodo' exists"
groupadd -g 999 opuser 2>/dev/null || echo "Group 'opuser' exists"
groupadd -g 1701 caddy 2>/dev/null || echo "Group 'caddy' exists"
groupadd -g 1702 caddyshared 2>/dev/null || echo "Group 'caddyshared' exists"

# Create users
useradd -u 568 -g 568 -m -s /bin/bash komodo 2>/dev/null || echo "User 'komodo' exists"
useradd -u 999 -g 999 -m -s /bin/bash opuser 2>/dev/null || echo "User 'opuser' exists"
useradd -u 1701 -g 1701 -m -s /bin/bash caddy 2>/dev/null || echo "User 'caddy' exists"

# Add to docker group
usermod -aG docker komodo
usermod -aG docker opuser
usermod -aG docker caddy

# Verify
id komodo
id opuser
id caddy
groups komodo | grep docker
```

**Expected Output:** All users exist with correct UIDs and are in docker group

### Step 7: Clone Repository

```bash
# Install git if needed
apt update && apt install -y git

# Clone repository
cd /mnt/apps01/repos
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab

# Pull latest changes (includes Phase 1 work)
git pull origin main

# Verify infrastructure files exist
ls -la stacks/infrastructure/
ls -la scripts/truenas-init-bootstrap.sh

# Set ownership
chown -R root:docker /mnt/apps01/repos/homelab
chmod -R 755 /mnt/apps01/repos/homelab
chmod +x /mnt/apps01/repos/homelab/scripts/*.sh
```

**Expected Output:** Repository cloned with all Phase 1 files present

### Step 8: Create Directory Structure

```bash
# Create all required directories
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
chmod 755 /mnt/apps01/appdata/op-connect
chmod 755 /mnt/apps01/appdata/komodo
chmod 755 /mnt/apps01/appdata/proxy
chmod 700 /mnt/apps01/appdata/komodo/mongodb
chmod 700 /mnt/apps01/appdata/proxy/caddy-data
chmod 770 /mnt/apps01/appdata/komodo/secrets
chmod 700 /mnt/apps01/secrets/op
chmod 700 /mnt/apps01/secrets/cloudflare

# Verify
ls -la /mnt/apps01/appdata/
ls -la /mnt/apps01/secrets/
```

**Expected Output:** All directories created with correct ownership

### Step 9: Copy Secrets from Workstation

**On your workstation:**

```bash
# Copy 1Password credentials
scp ~/homelab-secrets/1password-credentials.json root@barbary:/mnt/apps01/secrets/op/
scp ~/homelab-secrets/connect-token root@barbary:/mnt/apps01/secrets/op/

# Copy Cloudflare token
scp ~/homelab-secrets/cloudflare-api-token root@barbary:/mnt/apps01/secrets/cloudflare/api-token
```

**Back on TrueNAS:**

```bash
# Verify files arrived
ls -la /mnt/apps01/secrets/op/
ls -la /mnt/apps01/secrets/cloudflare/

# Verify credentials file is valid JSON
cat /mnt/apps01/secrets/op/1password-credentials.json | jq .
```

**Expected Output:** All secret files present and credentials file is valid JSON

### Step 10: Configure Permissions and ACLs on Secrets

```bash
# Set ownership and base permissions
chown root:root /mnt/apps01/secrets/op/*
chown root:root /mnt/apps01/secrets/cloudflare/*
chmod 600 /mnt/apps01/secrets/op/1password-credentials.json
chmod 600 /mnt/apps01/secrets/op/connect-token
chmod 600 /mnt/apps01/secrets/cloudflare/api-token

# Set ACLs for 1Password credentials (op-connect needs read)
setfacl -m u:999:r-- /mnt/apps01/secrets/op/1password-credentials.json
setfacl -m u:999:r-- /mnt/apps01/secrets/op/connect-token

# Set ACLs for connect token (komodo needs read for injection)
setfacl -m u:568:r-- /mnt/apps01/secrets/op/connect-token

# Set ACLs for Cloudflare token (caddy needs read)
setfacl -m u:1701:r-- /mnt/apps01/secrets/cloudflare/api-token

# Set directory execute permissions for traversal
chmod 750 /mnt/apps01/secrets/op
chmod 750 /mnt/apps01/secrets/cloudflare
setfacl -m u:999:r-x /mnt/apps01/secrets/op
setfacl -m u:568:r-x /mnt/apps01/secrets/op
setfacl -m u:1701:r-x /mnt/apps01/secrets/cloudflare

# Verify ACLs
getfacl /mnt/apps01/secrets/op/1password-credentials.json
getfacl /mnt/apps01/secrets/op/connect-token
getfacl /mnt/apps01/secrets/cloudflare/api-token
```

**Expected Output:** ACLs show user:999:r--, user:568:r--, user:1701:r-- on respective files

### Step 11: Configure Docker Socket

```bash
# Set Docker socket permissions
chmod 660 /var/run/docker.sock
chown root:docker /var/run/docker.sock

# Verify
ls -l /var/run/docker.sock

# Should show: srw-rw---- 1 root docker ... docker.sock
```

### Step 12: Test Permissions

```bash
# Test op-connect can read credentials
sudo -u '#999' cat /mnt/apps01/secrets/op/1password-credentials.json >/dev/null && echo "✓ opuser can read credentials" || echo "✗ FAIL"

# Test komodo can read token
sudo -u '#568' cat /mnt/apps01/secrets/op/connect-token >/dev/null && echo "✓ komodo can read token" || echo "✗ FAIL"

# Test caddy can read cloudflare token
sudo -u '#1701' cat /mnt/apps01/secrets/cloudflare/api-token >/dev/null && echo "✓ caddy can read cloudflare token" || echo "✗ FAIL"

# Test write permissions
sudo -u '#568' touch /mnt/apps01/appdata/komodo/mongodb/.test && \
sudo -u '#568' rm /mnt/apps01/appdata/komodo/mongodb/.test && echo "✓ komodo can write to mongodb" || echo "✗ FAIL"

sudo -u '#1701' touch /mnt/apps01/appdata/proxy/caddy-data/.test && \
sudo -u '#1701' rm /mnt/apps01/appdata/proxy/caddy-data/.test && echo "✓ caddy can write to caddy-data" || echo "✗ FAIL"

# Test Docker access
sudo -u komodo docker ps >/dev/null 2>&1 && echo "✓ komodo can access Docker" || echo "✗ FAIL"
```

**Expected Output:** All tests show ✓

**STOP HERE IF ANY TESTS FAIL** - Review permissions documentation before proceeding

---

## Infrastructure Deployment

### Step 13: Run Bootstrap Script (First Time)

```bash
# Run the bootstrap script
cd /mnt/apps01/repos/homelab
./scripts/truenas-init-bootstrap.sh

# The script will:
# 1. Initialize Docker Swarm (if not already)
# 2. Create overlay networks
# 3. Create Swarm secrets
# 4. Deploy op-connect stack (wait 30s)
# 5. Deploy komodo stack (wait 45s)
# 6. Deploy caddy stack (wait 15s)
```

**Expected Output:**
```
=========================================
Starting Homelab Infrastructure Bootstrap
=========================================
Verified prerequisites: Docker running, paths exist
Docker Swarm already active
Creating overlay networks...
Network already exists: proxy_network
Network already exists: op-connect_op-connect
Creating Swarm secrets...
Created secret: op_connect_token
Created secret: CLOUDFLARE_API_TOKEN
Directory structure created and permissions set
=========================================
Deploying Infrastructure Tier
=========================================
Deploying op-connect stack...
op-connect stack deployed successfully
Waiting 30 seconds for op-connect to initialize...
op-connect services are running
Deploying komodo stack...
komodo stack deployed successfully
Waiting 45 seconds for MongoDB initialization and Komodo startup...
komodo services are running
Deploying caddy stack...
caddy stack deployed successfully
Waiting 15 seconds for Caddy to initialize...
caddy services are running
=========================================
Infrastructure Bootstrap Complete
=========================================
```

### Step 14: Monitor Deployment

Open a second terminal and watch the deployment:

```bash
# Watch stack deployment
watch -n 2 'docker stack ls && echo "" && docker service ls'

# In another terminal, watch logs
docker service logs -f op-connect_op-connect-api

# Or watch all infrastructure services
docker service logs -f $(docker service ls --filter "label=com.docker.stack.namespace=op-connect" -q)
```

**Wait for all services to show "Running" state**

### Step 15: Verify Infrastructure Services

```bash
# Check Swarm status
docker info | grep -A 5 "Swarm:"

# Check networks
docker network ls | grep -E 'proxy_network|op-connect'

# Check secrets
docker secret ls

# Check stacks
docker stack ls

# Check all services
docker service ls

# Check service details
docker stack ps op-connect --no-trunc
docker stack ps komodo --no-trunc
docker stack ps caddy --no-trunc
```

**Expected Output:**
- Swarm: active
- 2 networks (proxy_network, op-connect_op-connect)
- 2 secrets (op_connect_token, CLOUDFLARE_API_TOKEN)
- 3 stacks running
- All services in "Running" state

### Step 16: Test Service Health

```bash
# Test op-connect API
docker exec $(docker ps -q -f name=op-connect-api) curl -s http://localhost:8080/health | jq .

# Should return: {"name":"1Password Connect API","version":"..."}

# Test MongoDB
docker exec $(docker ps -q -f name=komodo_mongo) mongosh --quiet --eval "db.adminCommand('ping')"

# Should return: { ok: 1 }

# Test Komodo API
docker exec $(docker ps -q -f name=komodo_core) curl -s http://localhost:30160/ || echo "Komodo redirects to login (expected)"
```

**Expected Output:** Services respond to health checks

### Step 17: Verify External Access

```bash
# Test DNS resolution (from TrueNAS)
dig +short komodo.in.hypyr.space
dig +short op-connect.in.hypyr.space

# Test Caddy is serving
curl -k -I https://komodo.in.hypyr.space

# Should return: HTTP/2 200 or 3xx redirect
```

**From your workstation browser:**

1. Navigate to: https://komodo.in.hypyr.space
2. Should see Komodo login page (no certificate errors if DNS propagated)
3. Create admin user on first visit

**Expected Output:** Komodo UI loads successfully with valid TLS certificate

### Step 18: Check Logs for Errors

```bash
# Check for errors in recent logs
docker service logs --tail 50 op-connect_op-connect-api 2>&1 | grep -i error
docker service logs --tail 50 komodo_mongo 2>&1 | grep -i error
docker service logs --tail 50 komodo_core 2>&1 | grep -i error
docker service logs --tail 50 caddy_caddy 2>&1 | grep -i error

# Check if secrets were injected successfully
docker service logs komodo_mongo 2>&1 | grep "op inject"
```

**Expected Output:** No critical errors, secrets injected successfully

---

## Post-Deployment Configuration

### Step 19: Configure Komodo

1. **Access Komodo UI:** https://komodo.in.hypyr.space
2. **Create Admin User:**
   - Username: admin (or your preference)
   - Password: (use password manager)
   - Email: your email

3. **Add Git Repository:**
   - Settings → Git Integration
   - Repository URL: https://github.com/YOUR_USERNAME/homelab.git
   - Branch: main
   - Enable sync

4. **Verify Periphery Connection:**
   - Servers → Should show "barbary-periphery" connected
   - Status: Online
   - Can view Docker resources

### Step 20: Install SystemD Service for Auto-Start

```bash
# Create systemd service
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
ExecStart=/mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh
StandardOutput=journal
StandardError=journal
TimeoutStartSec=600
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable service
systemctl enable homelab-bootstrap.service

# Check status
systemctl status homelab-bootstrap.service
```

**Expected Output:** Service enabled and active

### Step 21: Test Reboot Resilience

```bash
# Reboot TrueNAS
echo "Rebooting in 10 seconds... Press Ctrl+C to cancel"
sleep 10
reboot
```

**After reboot (2-5 minutes):**

```bash
# SSH back in
ssh root@barbary

# Check if services auto-started
docker stack ls
docker service ls

# All infrastructure services should be running
# Check systemd service
systemctl status homelab-bootstrap.service

# Should show: Active: active (exited)
```

**Expected Output:** All infrastructure services running after reboot

---

## Validation

### Step 22: Run Phase 1 Validation Checklist

```bash
# From the repository
cd /mnt/apps01/repos/homelab
cat docs/deployment/PHASE1_VALIDATION_CHECKLIST.md

# Work through the "Post-Deployment Validation" section
# Verify all checkboxes pass
```

### Step 23: Create ZFS Snapshots (Backup)

```bash
# Create snapshots of Phase 1 completed state
zfs snapshot apps01/appdata@phase1-complete
zfs snapshot apps01/secrets@phase1-complete
zfs snapshot apps01/repos@phase1-complete

# Verify snapshots
zfs list -t snapshot | grep phase1-complete

# To rollback if needed (emergency only):
# zfs rollback apps01/appdata@phase1-complete
```

---

## Troubleshooting

If anything fails, consult:

1. **Bootstrap logs:**
   ```bash
   tail -100 /var/log/homelab-bootstrap.log
   ```

2. **Service logs:**
   ```bash
   docker service logs SERVICE_NAME --tail 100
   ```

3. **SystemD journal:**
   ```bash
   journalctl -u homelab-bootstrap.service -n 100
   ```

4. **Permissions issues:**
   - See `docs/deployment/PERMISSIONS_REFERENCE.md`
   - Run permission test scripts

5. **Network issues:**
   ```bash
   docker network inspect proxy_network
   docker network inspect op-connect_op-connect
   ```

6. **Secrets issues:**
   ```bash
   docker secret ls
   docker secret inspect op_connect_token
   ```

---

## Phase 1 Complete Criteria

Phase 1 is considered complete when:

- [ ] All pre-deployment verification passed
- [ ] TrueNAS prerequisites configured (ZFS, users, permissions)
- [ ] Repository cloned with Phase 1 changes
- [ ] Secrets copied and ACLs configured
- [ ] Permission tests all passed
- [ ] Bootstrap script ran successfully
- [ ] All 3 stacks deployed (op-connect, komodo, caddy)
- [ ] All services in "Running" state
- [ ] Komodo UI accessible via HTTPS
- [ ] TLS certificates issued successfully
- [ ] SystemD service installed and enabled
- [ ] Reboot test passed (services auto-start)
- [ ] Validation checklist completed
- [ ] ZFS snapshots created

**Sign-off Date:** ___________

---

## Next Steps

With Phase 1 complete, you can proceed to:

**Phase 2: Platform Services**
- Deploy monitoring stack (Grafana, Loki, Prometheus)
- Deploy Wazuh SIEM
- Configure dashboards and alerting

**Reference:** `docs/adr/ADR-0033-truenas-swarm-migration.md`

---

## Quick Reference Commands

```bash
# View all infrastructure services
docker service ls --filter "label=com.docker.stack.namespace"

# Restart a stack
docker stack rm komodo && sleep 10 && \
docker stack deploy -c /mnt/apps01/repos/homelab/stacks/infrastructure/komodo-compose.yaml komodo

# View logs
docker service logs -f komodo_core

# Check service status
docker service ps komodo_core --no-trunc

# Update repository and redeploy
cd /mnt/apps01/repos/homelab && git pull && \
./scripts/truenas-init-bootstrap.sh
```
