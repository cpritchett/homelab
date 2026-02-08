# Phase 1: Infrastructure Foundation - Validation Checklist

This checklist ensures Phase 1 (Infrastructure Bootstrap) is properly configured and ready for production use before proceeding to Phase 2.

## Pre-Flight Checklist

Run this checklist **before** attempting the bootstrap for the first time.

### Hardware & OS

- [ ] TrueNAS Scale installed (version 24.04 Dragonfish or later)
- [ ] System has adequate resources:
  - [ ] Minimum 16GB RAM (32GB+ recommended)
  - [ ] Minimum 4 CPU cores (8+ recommended)
  - [ ] QuickSync-capable CPU if transcoding needed (Intel Gen 7-12)
- [ ] Network interface configured with static IP
- [ ] System hostname set correctly (`barbary.hypyr.space`)
- [ ] SSH access working for remote administration

### Storage Configuration

- [ ] Primary pool created (`apps01` - SSD recommended)
  - [ ] Dataset: `apps01/appdata` (container persistent data)
  - [ ] Dataset: `apps01/secrets` (credential files)
  - [ ] Dataset: `apps01/repos` (Git repositories)
- [ ] Secondary pool created (`data01` - HDD acceptable)
  - [ ] Dataset: `data01/data` (media libraries)
- [ ] Mount points verified:
  ```bash
  ls -la /mnt/apps01/
  ls -la /mnt/data01/
  ```

### Docker Configuration

- [ ] Docker service enabled in TrueNAS:
  - Applications → Settings → Advanced → Enable Docker
- [ ] Docker service running:
  ```bash
  systemctl status docker
  ```
- [ ] Docker CLI accessible:
  ```bash
  docker info
  ```

### Repository Setup

- [ ] Git installed on TrueNAS:
  ```bash
  apt install git -y  # If not pre-installed
  ```
- [ ] Homelab repository cloned:
  ```bash
  cd /mnt/apps01/repos
  git clone https://github.com/YOUR_USERNAME/homelab.git
  ```
- [ ] Repository accessible:
  ```bash
  ls -la /mnt/apps01/repos/homelab/stacks/infrastructure/
  ```
- [ ] Repository on correct branch (typically `main`)

### 1Password Connect Credentials

- [ ] 1Password CLI installed on workstation
- [ ] 1Password CLI authenticated:
  ```bash
  op account list
  ```
- [ ] Connect server credentials generated:
  ```bash
  op connect server create barbary --vaults homelab
  ```
- [ ] Credentials copied to TrueNAS:
  - [ ] `/mnt/apps01/secrets/op/1password-credentials.json` exists
  - [ ] `/mnt/apps01/secrets/op/connect-token` exists
- [ ] Credentials file permissions set:
  ```bash
  chmod 600 /mnt/apps01/secrets/op/*
  ls -la /mnt/apps01/secrets/op/
  ```
- [ ] Credentials file is valid JSON:
  ```bash
  cat /mnt/apps01/secrets/op/1password-credentials.json | jq .
  ```

### Cloudflare Configuration

- [ ] Cloudflare account has hypyr.space domain
- [ ] API token created with permissions:
  - Zone:DNS:Edit for hypyr.space
  - Zone:Zone:Read for hypyr.space
- [ ] Token saved to TrueNAS:
  ```bash
  echo "YOUR_TOKEN" > /mnt/apps01/secrets/cloudflare/api-token
  chmod 600 /mnt/apps01/secrets/cloudflare/api-token
  ```
- [ ] Token tested (optional):
  ```bash
  curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $(cat /mnt/apps01/secrets/cloudflare/api-token)" | jq .
  ```

### DNS Configuration

- [ ] DNS records created in Cloudflare:
  - [ ] `barbary.hypyr.space` → A record → TrueNAS IP
  - [ ] `op-connect.in.hypyr.space` → CNAME → `barbary.hypyr.space`
  - [ ] `komodo.in.hypyr.space` → CNAME → `barbary.hypyr.space`
  - [ ] `*.in.hypyr.space` → CNAME → `barbary.hypyr.space` (wildcard)
- [ ] DNS propagation verified:
  ```bash
  dig barbary.hypyr.space +short
  dig komodo.in.hypyr.space +short
  ```

### 1Password Vault Structure

- [ ] Vault named `homelab` exists in 1Password
- [ ] Item `Komodo - Barbary` exists with fields:
  - [ ] Field: `Database` (MongoDB password)
  - [ ] Field: `credential` (Komodo passkey)
- [ ] Test secret references (optional):
  ```bash
  op read "op://homelab/Komodo - Barbary/Database"
  op read "op://homelab/Komodo - Barbary/credential"
  ```

### Bootstrap Script

- [ ] Script exists:
  ```bash
  ls -la /mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh
  ```
- [ ] Script is executable:
  ```bash
  chmod +x /mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh
  ```
- [ ] Script has correct paths (verify REPO_PATH, SECRETS_PATH, APPDATA_PATH)

## Deployment Checklist

Run this checklist **during** the first bootstrap deployment.

### Initial Bootstrap Execution

- [ ] Run bootstrap script manually (first time):
  ```bash
  /mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh
  ```
- [ ] Monitor logs:
  ```bash
  tail -f /var/log/homelab-bootstrap.log
  ```
- [ ] Script completes without errors
- [ ] Log shows all three stacks deployed:
  - op-connect
  - komodo
  - caddy

### Docker Swarm Validation

- [ ] Swarm initialized:
  ```bash
  docker info | grep "Swarm: active"
  ```
- [ ] Node is manager:
  ```bash
  docker node ls
  # Should show barbary as Leader
  ```
- [ ] Swarm advertise address is correct:
  ```bash
  docker info | grep "Advertise"
  ```

### Network Validation

- [ ] Overlay networks created:
  ```bash
  docker network ls | grep overlay
  # Should show:
  #   - proxy_network
  #   - op-connect_op-connect
  ```
- [ ] Networks are attachable:
  ```bash
  docker network inspect proxy_network | jq '.[0].Attachable'
  # Should return: true
  ```

### Secrets Validation

- [ ] Swarm secrets created:
  ```bash
  docker secret ls
  # Should show:
  #   - op_connect_token
  #   - CLOUDFLARE_API_TOKEN
  ```
- [ ] Secrets cannot be read (security):
  ```bash
  docker secret inspect op_connect_token
  # Should show metadata only, not actual secret value
  ```

### Stack Validation

- [ ] All stacks deployed:
  ```bash
  docker stack ls
  # Should show:
  #   - op-connect (2 services)
  #   - komodo (3 services)
  #   - caddy (1-2 services)
  ```
- [ ] All services running:
  ```bash
  docker stack ps op-connect --no-trunc
  docker stack ps komodo --no-trunc
  docker stack ps caddy --no-trunc
  # All should be "Running"
  ```

### Service Health Checks

#### 1Password Connect

- [ ] op-connect-api container running:
  ```bash
  docker service ps op-connect_op-connect-api
  ```
- [ ] op-connect-sync container running:
  ```bash
  docker service ps op-connect_op-connect-sync
  ```
- [ ] Health check responds:
  ```bash
  docker exec $(docker ps -q -f name=op-connect-api) \
    curl -s http://localhost:8080/health | jq .
  # Should return version info
  ```
- [ ] Can retrieve secrets:
  ```bash
  # From within a container that has op_connect_token
  curl -H "Authorization: Bearer $(cat /run/secrets/op_connect_token)" \
    http://op-connect-api:8080/v1/vaults | jq .
  ```

#### Komodo

- [ ] MongoDB initialized:
  ```bash
  docker service logs komodo_mongo --tail 50
  # Should show "Waiting for connections" message
  ```
- [ ] Komodo core running:
  ```bash
  docker service ps komodo_core
  ```
- [ ] Komodo periphery running:
  ```bash
  docker service ps komodo_periphery
  ```
- [ ] Secrets injected successfully:
  ```bash
  docker service logs komodo_mongo --tail 100 | grep "op inject"
  # Should show successful secret injection
  ```

#### Caddy

- [ ] Caddy service running:
  ```bash
  docker service ps caddy_caddy
  ```
- [ ] Caddy logs show certificate acquisition:
  ```bash
  docker service logs caddy_caddy --tail 100
  # Look for "certificate obtained successfully" messages
  ```
- [ ] DNS challenge working (no errors about Cloudflare API)

### External Accessibility

- [ ] Komodo UI accessible via HTTPS:
  ```bash
  curl -k -I https://komodo.in.hypyr.space
  # Should return HTTP 200 or redirect
  ```
- [ ] Browser test: https://komodo.in.hypyr.space
  - [ ] Page loads without certificate errors
  - [ ] Login page displays
  - [ ] Can create admin user (first time only)
- [ ] op-connect accessible (internal only):
  ```bash
  # From another container
  curl http://op-connect-api:8080/health
  ```

### TLS Certificate Validation

- [ ] Certificate issued by Let's Encrypt:
  ```bash
  echo | openssl s_client -servername komodo.in.hypyr.space \
    -connect komodo.in.hypyr.space:443 2>/dev/null | \
    openssl x509 -noout -issuer
  # Should show: issuer=C = US, O = Let's Encrypt...
  ```
- [ ] Certificate is valid (not expired):
  ```bash
  echo | openssl s_client -servername komodo.in.hypyr.space \
    -connect komodo.in.hypyr.space:443 2>/dev/null | \
    openssl x509 -noout -dates
  ```
- [ ] Certificate covers correct domain:
  ```bash
  echo | openssl s_client -servername komodo.in.hypyr.space \
    -connect komodo.in.hypyr.space:443 2>/dev/null | \
    openssl x509 -noout -subject
  ```

### Persistence Validation

- [ ] Data directories created:
  ```bash
  ls -la /mnt/apps01/appdata/op-connect/
  ls -la /mnt/apps01/appdata/komodo/mongodb/
  ls -la /mnt/apps01/appdata/proxy/caddy-data/
  ```
- [ ] Permissions correct:
  ```bash
  stat /mnt/apps01/appdata/proxy | grep Uid
  # Should show: Uid: ( 1701/...)
  stat /mnt/apps01/appdata/komodo | grep Uid
  # Should show: Uid: (  568/...)
  ```
- [ ] Volumes contain data:
  ```bash
  du -sh /mnt/apps01/appdata/komodo/mongodb/
  # Should show non-zero size
  ```

## Post-Deployment Validation

Run this checklist **after** the bootstrap is complete.

### SystemD Service Setup

- [ ] Service file created:
  ```bash
  cat /etc/systemd/system/homelab-bootstrap.service
  ```
- [ ] Daemon reloaded:
  ```bash
  systemctl daemon-reload
  ```
- [ ] Service enabled:
  ```bash
  systemctl is-enabled homelab-bootstrap.service
  # Should return: enabled
  ```
- [ ] Service status healthy:
  ```bash
  systemctl status homelab-bootstrap.service
  # Should show: Active: active (exited)
  ```

### Reboot Test

- [ ] Reboot TrueNAS:
  ```bash
  reboot
  ```
- [ ] Wait for system to come back up (2-5 minutes)
- [ ] SSH back in and verify services auto-started:
  ```bash
  docker stack ls
  docker service ls
  ```
- [ ] All infrastructure services running without manual intervention
- [ ] Komodo UI accessible immediately after boot

### Komodo Configuration

- [ ] Admin user created in Komodo UI
- [ ] Git integration configured:
  - [ ] Repository: https://github.com/YOUR_USERNAME/homelab.git
  - [ ] Branch: main
  - [ ] Sync enabled
- [ ] Periphery server auto-discovered:
  - [ ] Server name: barbary-periphery
  - [ ] Status: Connected
  - [ ] Can view Docker resources

### Monitoring & Logging

- [ ] Bootstrap logs accessible:
  ```bash
  tail -100 /var/log/homelab-bootstrap.log
  ```
- [ ] SystemD journal captured:
  ```bash
  journalctl -u homelab-bootstrap.service -n 100
  ```
- [ ] Service logs accessible:
  ```bash
  docker service logs op-connect_op-connect-api --tail 50
  docker service logs komodo_core --tail 50
  docker service logs caddy_caddy --tail 50
  ```

### Backup Validation

- [ ] Critical secrets backed up to 1Password vault:
  - [ ] op_connect_token
  - [ ] CLOUDFLARE_API_TOKEN
  - [ ] Komodo admin credentials
- [ ] ZFS snapshots configured (optional but recommended):
  ```bash
  zfs snapshot apps01/appdata@phase1-complete
  zfs snapshot apps01/secrets@phase1-complete
  ```

## Troubleshooting Reference

If any checklist item fails, refer to:

- **Bootstrap script logs:** `/var/log/homelab-bootstrap.log`
- **Service-specific logs:** `docker service logs SERVICE_NAME`
- **SystemD journal:** `journalctl -u homelab-bootstrap.service`
- **Detailed troubleshooting:** See `docs/deployment/TRUENAS_BOOTSTRAP_SETUP.md`

Common issues and quick fixes:

| Issue | Quick Fix |
|-------|-----------|
| Swarm not initialized | `docker swarm init --advertise-addr $(hostname -I \| awk '{print $1}')` |
| Networks missing | Re-run bootstrap script (idempotent) |
| Secrets missing | Verify files in `/mnt/apps01/secrets/` then re-run bootstrap |
| op-connect fails | Check credentials JSON is valid: `cat /mnt/apps01/secrets/op/1password-credentials.json \| jq .` |
| Komodo MongoDB errors | Wait 60s for initialization, check logs: `docker service logs komodo_mongo` |
| Caddy certificate errors | Verify Cloudflare token, check DNS propagation: `dig komodo.in.hypyr.space` |

## Phase 1 Completion Criteria

Phase 1 is considered **complete and ready for Phase 2** when:

- [x] All items in Pre-Flight Checklist are checked
- [x] All items in Deployment Checklist are checked
- [x] All items in Post-Deployment Validation are checked
- [ ] System has run for 24 hours without infrastructure service failures
- [ ] At least one reboot cycle completed successfully
- [ ] Team can access Komodo UI and understands basic operations
- [ ] Documentation reviewed and understood by all team members

**Sign-off:**
- Infrastructure Lead: ___________________ Date: ___________
- Security Review: ___________________ Date: ___________

## Next Steps

With Phase 1 complete, proceed to:

**Phase 2: Platform Services Deployment**
- Deploy monitoring stack (see `docs/deployment/PHASE2_MONITORING.md`)
- Deploy Wazuh SIEM
- Configure dashboards and alerting
- Integrate with existing Kubernetes monitoring

**Reference Documents:**
- Main migration plan: `docs/adr/ADR-0033-truenas-swarm-migration.md`
- Bootstrap setup guide: `docs/deployment/TRUENAS_BOOTSTRAP_SETUP.md`
