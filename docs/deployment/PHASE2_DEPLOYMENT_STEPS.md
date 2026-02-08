# Phase 2: Platform Services Deployment Steps

This guide provides the specific steps to deploy Phase 2 platform services via Komodo UI.

**Note**: This guide is written for Komodo v2-dev. The exact UI navigation and button labels may differ from what's described here. Focus on the **Configuration Target** sections for each stack - these describe the settings you need to configure regardless of UI layout.

## Prerequisites

- ✅ Phase 1 infrastructure tier deployed and healthy
- ✅ Komodo UI accessible at https://komodo.in.hypyr.space
- ✅ Repository pulled to TrueNAS: `/mnt/apps01/repos/homelab`
- ✅ All Swarm secrets created (from Phase 1)

## One-Time Setup: Configure Repository in Stack

Komodo v2 handles Git integration directly in each Stack resource. You'll configure the repository details when creating each stack using the **Source** settings in the GENERAL section.

## Stack Deployment Order

Deploy in this order to satisfy dependencies:

### 1. Observability Stack (Homepage + Uptime Kuma)

**Purpose**: Combined dashboard and monitoring services

**Prerequisites:**
```bash
# Create data directories
sudo mkdir -p /mnt/apps01/appdata/homepage/{config,icons,images}
sudo mkdir -p /mnt/apps01/appdata/uptime-kuma
sudo chown -R 1000:1000 /mnt/apps01/appdata/homepage
sudo chown -R 1000:1000 /mnt/apps01/appdata/uptime-kuma
```

**Create Stack in Komodo UI:**

1. Navigate to **Stacks** and create a new Stack named `platform_observability`
2. Select **Server**: `barbary-periphery` (your Swarm manager)

3. **Files** section:
   - **Run Directory**: `stacks/platform/observability/`
   - **File Paths**: Leave empty (uses default `compose.yaml`)

4. **Config Files** (optional - to edit in Komodo UI):
   - `homepage/config/services.yaml`
   - `homepage/config/settings.yaml`
   - `homepage/config/bookmarks.yaml`

5. **Save** and **Deploy**
6. Monitor deployment - 3 services should start:
   - homepage (1/1)
   - uptime-kuma (1/1)
   - docker-socket-proxy (1/1)

**Verify:**

**Homepage:**
- Access https://home.in.hypyr.space
- Should see dashboard with infrastructure services listed
- Docker integration should show running containers

**Uptime Kuma:**
- Access https://status.in.hypyr.space
- Complete initial setup (create admin user)
- Add monitors for infrastructure services:
  1. Komodo: https://komodo.in.hypyr.space
  2. 1Password Connect: http://op-connect-api:8080/health
  3. Homepage: https://home.in.hypyr.space

**Troubleshooting:**

**Homepage issues:**
- If container fails to start, check logs in Komodo UI
- Verify config files exist: `ls -la /mnt/apps01/appdata/homepage/config/`
- Check service: `docker service ps platform_observability_homepage`

**Uptime Kuma issues:**
- Check directory permissions: `ls -la /mnt/apps01/appdata/uptime-kuma`
- Should be owned by 1000:1000
- Check service: `docker service ps platform_observability_uptime-kuma`

**External access fails (502/503):**
- Check Caddy labels: `docker service inspect platform_observability_homepage --format '{{json .Spec.Labels}}'`
- Verify services are on proxy_network
- Check Caddy logs: `docker service logs caddy_caddy`

---

### 3. Authentik SSO

**Purpose**: Single Sign-On and authentication for all services

**Prerequisites:**
```bash
# Create directory structure
sudo mkdir -p /mnt/apps01/appdata/authentik/{media,custom-templates,secrets}
sudo mkdir -p /mnt/data01/appdata/authentik/{postgres,redis}

# Set ownership
sudo chown -R 1000:1000 /mnt/apps01/appdata/authentik
sudo chown -R 999:999 /mnt/data01/appdata/authentik/postgres
sudo chown -R 999:999 /mnt/data01/appdata/authentik/redis

# Secrets directory needs special handling (will be written by secrets-init)
sudo chmod 755 /mnt/apps01/appdata/authentik/secrets
```

**Important: Secrets Setup**

Before deploying, you need to create the 1Password templates. Check if they exist:

```bash
ls -la /mnt/apps01/repos/homelab/stacks/platform/auth/authentik/*.template
```

Expected files:
- `env.template` - Main Authentik environment variables
- `postgres.template` - PostgreSQL credentials

If templates are missing, you'll need to create them or the secrets-init container will fail.

**Create Stack in Komodo UI:**

1. Create new Stack named `platform_authentik`
2. Select **Server**: `barbary-periphery`

3. **Files** section:
   - **Run Directory**: `stacks/platform/auth/authentik/`
   - **File Paths**: Leave empty (will use default `compose.yaml`)

4. **Config Files** (optional):
   - Add `env.template` and `postgres.template` if you want to edit them in Komodo UI

5. **Save** and **Deploy**
6. Monitor deployment - this stack has 5 services:
   - secrets-init (runs once, will show 0/0 when complete - this is expected)
   - postgresql (1/1)
   - redis (1/1)
   - authentik-server (1/1)
   - authentik-worker (1/1)

**Deployment Notes:**
- The `secrets-init` container will run once to create `/mnt/apps01/appdata/authentik/secrets/*.env` files
- It will exit after creating secrets (this is expected)
- Other services will start after secrets are created
- Initial startup may take 2-3 minutes for PostgreSQL initialization

**Verify:**
1. Check secrets were created:
   ```bash
   ls -la /mnt/apps01/appdata/authentik/secrets/
   # Should show: authentik.env and postgres.env
   ```

2. Check all services are running:
   ```bash
   docker service ls | grep authentik
   # Should show: 5 services (secrets-init shows 0/0 - expected)
   # postgresql, redis, authentik-server, authentik-worker should be 1/1
   ```

3. Access https://auth.in.hypyr.space
4. Complete Authentik setup wizard:
   - Create admin user
   - Set admin password (use password manager!)
   - Note: Keep admin credentials safe, they're needed for provider setup

**Post-Deployment Configuration:**

1. **Create Application Provider for Homepage:**
   - Applications → Providers → Create
   - Type: Proxy Provider
   - Name: `Homepage`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Forward auth (single application): Yes
   - External host: `https://home.in.hypyr.space`

2. **Create Application Provider for Uptime Kuma:**
   - Applications → Providers → Create
   - Type: Proxy Provider
   - Name: `Uptime Kuma`
   - Forward auth (single application): Yes
   - External host: `https://status.in.hypyr.space`

3. **Update Caddy configuration** to use forward-auth (Phase 3)

**Troubleshooting:**

- **secrets-init fails**: Check op-connect is running and accessible
  ```bash
  docker service ls | grep op-connect
  curl http://op-connect-api:8080/health
  ```

- **PostgreSQL won't start**: Check directory permissions
  ```bash
  ls -ld /mnt/data01/appdata/authentik/postgres
  # Should be owned by 999:999
  ```

- **Authentik server fails**: Check secrets exist
  ```bash
  cat /mnt/apps01/appdata/authentik/secrets/authentik.env
  # Should have AUTHENTIK_SECRET_KEY and other vars
  ```

- **Services stuck in "Starting"**: Check logs
  ```bash
  docker service logs platform_authentik_postgresql
  docker service logs platform_authentik_authentik-server
  ```

---

## Validation

After deploying all three stacks, verify:

1. **All stacks visible in Komodo UI:**
   - platform_homepage
   - platform_uptime_kuma
   - platform_authentik

2. **All services healthy:**
   ```bash
   docker service ls
   # All platform services should show 1/1 (except secrets-init: 0/0)
   ```

3. **External access:**
   - https://home.in.hypyr.space - Homepage dashboard
   - https://status.in.hypyr.space - Uptime Kuma
   - https://auth.in.hypyr.space - Authentik login

4. **Homepage showing services:**
   - Check that Infrastructure and Platform sections populate
   - Docker integration working (shows container status)

5. **Uptime Kuma monitors running:**
   - All configured monitors showing "Up"
   - Status page accessible

6. **Authentik ready:**
   - Admin login works
   - Applications and Providers menus accessible
   - Ready to configure SSO providers

## Next Phase

With Platform Tier deployed, proceed to:

**Phase 2B: Monitoring Stack**
- Create Prometheus/Grafana/Loki stack
- Wire metrics from all services
- Configure Grafana dashboards
- Set up alerting

**Phase 3: Application Tier**
- Deploy media stack (Plex, Sonarr, Radarr, etc.)
- Deploy home automation (Home Assistant)
- Deploy additional services as needed

## Stack Management via Komodo

### Updating a Stack

1. Make changes to compose file in GitHub
2. Commit and push to `main` branch
3. In Komodo UI:
   - Navigate to the stack
   - Click **Redeploy** (pulls latest from Git)
   - Or wait for auto-sync (5 minutes)

### Viewing Logs

1. In Komodo UI, navigate to stack
2. Click **Logs** tab
3. Select service to view logs
4. Or via CLI:
   ```bash
   docker service logs platform_homepage_homepage
   ```

### Removing a Stack

1. In Komodo UI, navigate to stack
2. Click **Actions → Delete**
3. Confirm deletion
4. Or via CLI:
   ```bash
   docker stack rm platform_homepage
   ```

## Common Issues

### Stack won't deploy

- **Check Git path**: Ensure path in Komodo matches actual file location
- **Validate compose file**: Test locally with `docker stack deploy --compose-file compose.yaml test-stack`
- **Check networks**: Ensure `proxy_network` and `op-connect_op-connect` exist

### Service stuck in "Starting"

- **Check logs**: View in Komodo UI or via `docker service logs`
- **Check resource limits**: May need to increase memory/CPU limits
- **Check dependencies**: Ensure required networks/secrets exist

### External access fails (502/503)

- **Check Caddy**: Verify Caddy stack is running
  ```bash
  docker service ls | grep caddy
  ```
- **Check service health**: Ensure service is responding internally
  ```bash
  docker exec <container> wget -qO- http://localhost:<port>
  ```
- **Check DNS**: Verify DNS points to TrueNAS IP
  ```bash
  dig home.in.hypyr.space
  ```

### Secrets not loading

- **Check secrets-init logs**:
  ```bash
  docker service logs platform_authentik_secrets-init
  ```
- **Verify op-connect**: Ensure op-connect stack is healthy
- **Check secret files**: Verify files created in `/mnt/apps01/appdata/{service}/secrets/`
- **Check file permissions**: Should be readable by service user

## Support and Documentation

- **Komodo Documentation**: https://github.com/moghtech/komodo
- **Docker Swarm Docs**: https://docs.docker.com/engine/swarm/
- **Homepage Docs**: https://gethomepage.dev
- **Authentik Docs**: https://docs.goauthentik.io
- **Uptime Kuma Docs**: https://github.com/louislam/uptime-kuma/wiki
