# Observability Stack

Combined stack for homelab observability and monitoring services.

## Services

### Homepage Dashboard
- **URL**: https://home.in.hypyr.space
- **Purpose**: Centralized dashboard for monitoring all homelab services
- **Integration**: Docker socket proxy for label-based auto-discovery
- **Config**: `/mnt/apps01/appdata/homepage/config/` (manual config in services.yaml is optional - labels are preferred)
- **Pattern**: Auto-discovers services with `homepage.*` labels

### Uptime Kuma
- **URL**: https://status.in.hypyr.space
- **Purpose**: Uptime monitoring and status page
- **Data**: `/mnt/apps01/appdata/uptime-kuma/`
- **Integration**: AutoKuma for label-based monitor auto-creation

### AutoKuma
- **Purpose**: Automatically create Uptime Kuma monitors from Docker labels
- **Source**: https://github.com/BigBoot/AutoKuma
- **Label Pattern**: `kuma.<monitor-id>.<type>.<setting>`
- **Sync Interval**: 60 seconds
- **Tag**: All auto-created monitors tagged with "autokuma"

### Docker Socket Proxy
- **Purpose**: Secure, read-only access to Docker API for Homepage and AutoKuma
- **Permissions**: Containers, Services, Tasks, Networks, Nodes, Info, Version
- **Internal only** - not exposed externally

## Deployment

**Prerequisites:**
```bash
# Create data directories
sudo mkdir -p /mnt/apps01/appdata/homepage/{config,icons,images}
sudo mkdir -p /mnt/apps01/appdata/uptime-kuma
sudo chown -R 1000:1000 /mnt/apps01/appdata/homepage
sudo chown -R 1000:1000 /mnt/apps01/appdata/uptime-kuma
```

**Deploy via Komodo:**
- Stack Name: `platform_observability`
- Run Directory: `stacks/platform/observability/`
- File Paths: Leave empty (uses compose.yaml)

**Config Files** (optional to edit in Komodo UI):
- `homepage/config/services.yaml`
- `homepage/config/settings.yaml`
- `homepage/config/bookmarks.yaml`
- `homepage/config/widgets.yaml`
- `homepage/config/docker.yaml`

## Architecture

```
┌─────────────────────────────────────────┐
│   Observability Stack                   │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │   Homepage   │  │  Uptime Kuma    │ │
│  │              │  │                 │ │
│  │  :3000       │  │     :3001       │ │
│  └──────┬───────┘  └────────┬────────┘ │
│         │                   │          │
│         │  ┌────────────────┘          │
│         │  │                           │
│         │  │  proxy_network            │
│         │  │  (Caddy ingress)          │
│         │  │                           │
│  ┌──────┴──┴──────┐                    │
│  │ Docker Socket  │                    │
│  │     Proxy      │                    │
│  │    :2375       │                    │
│  └────────────────┘                    │
│         │                              │
└─────────┼──────────────────────────────┘
          │
          │ read-only
          ↓
    /var/run/docker.sock
```

## Networks

- **proxy_network** (external): Caddy reverse proxy ingress
- **observability_internal** (overlay): Internal communication for socket proxy

## Post-Deployment

### 1. Configure Uptime Kuma (First Time)

**Step 1: Complete Initial Setup**
1. Access https://status.in.hypyr.space
2. Select "Embedded MariaDB" (recommended)
3. Click "Next"
4. Create admin account:
   - Username: `admin` (or your preference)
   - Password: (use strong password, save in password manager)
5. Complete setup wizard

**Step 2: Create API Key for AutoKuma**

AutoKuma uses an API key to authenticate with Uptime Kuma.

**In Uptime Kuma UI:**
1. Go to https://status.in.hypyr.space
2. Click **Settings** (gear icon in top-right)
3. Navigate to **"API Keys"** section
4. Click **"Add API Key"** or **"Generate"**
5. Give it a name: `AutoKuma`
6. Set expiration: **Never** (or long-lived)
7. Click **"Generate"** or **"Save"**
8. **Copy the API key** (shown only once!)

**Create Docker Secret (via SSH):**

```bash
# SSH to TrueNAS
ssh truenas_admin@barbary

# Create API key secret (paste the key you copied from Uptime Kuma)
echo "uk1_xxxxxxxxxxxxxxxxxxxxxxxxxx" | sudo docker secret create uptime_kuma_api_key -

# Verify secret was created
sudo docker secret ls | grep uptime_kuma
```

**Expected output:**
```
uptime_kuma_api_key   <timestamp>
```

**Redeploy the observability stack** to pick up the new secret:

Via Komodo UI:
1. Navigate to Komodo → Stacks → platform_observability
2. Sync repository (to get latest compose.yaml with API key support)
3. Click "Deploy" or "Redeploy"

Or via CLI:
```bash
cd /mnt/apps01/repos/homelab
sudo git pull origin main
sudo docker stack deploy -c stacks/platform/observability/compose.yaml platform_observability
```

**Step 3: Verify AutoKuma Connection**

Wait 60 seconds for AutoKuma to sync, then check:

```bash
# Check AutoKuma logs
sudo docker service logs platform_observability_autokuma --tail 20

# Look for successful sync messages:
# ✅ "Syncing monitors..."
# ✅ "Created monitor: Komodo UI"
# ✅ No "username/password" errors
```

**Step 4: Check Monitors in Uptime Kuma**

1. Go to https://status.in.hypyr.space
2. You should see monitors appearing with tag "autokuma" (blue)
3. AutoKuma creates monitors for all services with `kuma.*` labels

**Monitors Created Automatically:**
- Komodo UI (https://komodo.in.hypyr.space)
- 1Password Connect API (internal)
- Caddy Reverse Proxy (via Homepage)
- Homepage Dashboard
- Uptime Kuma (self-monitoring)
- Authentik SSO (once deployed)
- Any other services with AutoKuma labels

### 2. Configure Homepage (Optional)

Homepage auto-discovers services from Docker labels. Manual configuration is optional.

**Auto-Discovery (Recommended)**:
- Services with `homepage.*` labels automatically appear
- No manual `services.yaml` editing needed
- See `COMPLETE_LABEL_EXAMPLES.md` for examples

**Manual Configuration** (for services without labels):
1. Access https://home.in.hypyr.space
2. Edit `services.yaml` via Komodo UI or SSH
3. Homepage auto-reloads on config changes

### 3. Add Labels to Services

**ALL services should include these three label sets** for complete integration:

#### Complete Label Example

```yaml
services:
  myapp:
    deploy:
      labels:
        # Homepage: Dashboard display
        homepage.group: "Applications"
        homepage.name: "My Application"
        homepage.icon: "myapp.png"
        homepage.href: "https://myapp.in.hypyr.space"
        homepage.description: "Application description"

        # Caddy: Reverse proxy (if publicly accessible)
        caddy: myapp.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 8080}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: Uptime monitoring
        kuma.myapp.http.name: "My Application"
        kuma.myapp.http.url: "https://myapp.in.hypyr.space"
        kuma.myapp.http.interval: "60"
```

See `COMPLETE_LABEL_EXAMPLES.md` for comprehensive examples.

#### Homepage Label Patterns

Add labels to your service's `deploy.labels` section:

**Homepage Dashboard Labels:**
```yaml
homepage.group: "Applications"
homepage.name: "My Application"
homepage.icon: "myapp.png"  # or mdi-* for Material Design Icons
homepage.href: "https://myapp.in.hypyr.space"
homepage.description: "Application description"
# Optional widget:
homepage.widget.type: "customapi"
homepage.widget.url: "https://myapp.in.hypyr.space/api"
```

#### AutoKuma Label Patterns

**HTTP Monitor Example:**
```yaml
kuma.myapp.http.name: "My Application"
kuma.myapp.http.url: "https://myapp.in.hypyr.space"
kuma.myapp.http.interval: "60"
kuma.myapp.http.retryInterval: "60"
kuma.myapp.http.maxretries: "3"
```

**TCP Port Monitor Example:**
```yaml
kuma.database.port.name: "PostgreSQL Database"
kuma.database.port.hostname: "postgres"
kuma.database.port.port: "5432"
kuma.database.port.interval: "60"
```

**Docker Container Monitor Example:**
```yaml
kuma.container.docker.name: "Redis Container"
kuma.container.docker.docker_container: "redis"
kuma.container.docker.docker_host: "1"  # Use AutoKuma's Docker connection
```

**Monitor Types Supported:**
- `http` / `https` - HTTP(S) endpoint monitoring
- `port` - TCP port checks
- `ping` - ICMP ping
- `keyword` - HTTP with keyword search
- `docker` - Docker container status
- `dns` - DNS record checking
- And many more (see [AutoKuma docs](https://github.com/BigBoot/AutoKuma))

**Common Settings:**
- `name` - Monitor display name (required)
- `interval` - Check interval in seconds (default: 60)
- `retryInterval` - Retry interval in seconds (default: 60)
- `maxretries` - Max retry attempts (default: 3)
- `notificationIDList` - Comma-separated notification IDs

AutoKuma scans for labels every 60 seconds and auto-creates/updates monitors.

## Monitoring

**Service Health:**
```bash
docker service ls | grep observability
docker service ps platform_observability_homepage
docker service ps platform_observability_uptime-kuma
```

**Logs:**
```bash
docker service logs platform_observability_homepage
docker service logs platform_observability_uptime-kuma
docker service logs platform_observability_docker-socket-proxy
```

## Troubleshooting

### Homepage can't connect to Docker
- Check docker-socket-proxy is running: `docker service ps platform_observability_docker-socket-proxy`
- Verify Homepage can reach it: `docker exec <homepage-container> wget -qO- http://docker-socket-proxy:2375/_ping`

### Uptime Kuma data not persisting
- Check directory permissions: `ls -la /mnt/apps01/appdata/uptime-kuma`
- Should be owned by 1000:1000

### External access fails (502/503)
- Check Caddy labels are applied: `docker service inspect platform_observability_homepage --format '{{json .Spec.Labels}}'`
- Verify both services are on proxy_network
- Check Caddy logs: `docker service logs caddy_caddy`

### AutoKuma not creating monitors

**Symptom:** No monitors appearing in Uptime Kuma with "autokuma" tag

**Check logs:**
```bash
sudo docker service logs platform_observability_autokuma --tail 50
```

**Common errors and fixes:**

1. **Error:** `"server is expecting a username/password, but none was provided"` or authentication errors
   - **Cause:** Uptime Kuma API key not configured
   - **Fix:** Create API key in Uptime Kuma UI and add as Docker secret `uptime_kuma_api_key` (see Post-Deployment Step 2 above)
   - **Verify:** `sudo docker secret ls | grep uptime_kuma_api_key`

2. **Error:** `"Timeout while trying to connect to Uptime Kuma server"`
   - **Cause:** Uptime Kuma not fully initialized
   - **Fix:** Wait for Uptime Kuma to complete startup (check: `docker service ps platform_observability_uptime-kuma`)

3. **Error:** `"Error during connect"`
   - **Cause:** Network connectivity issue
   - **Fix:** Verify both services are on observability_internal network

4. **No errors, but no monitors created:**
   - **Cause:** No services with `kuma.*` labels deployed yet
   - **Check:** `docker service inspect komodo_core --format '{{json .Spec.Labels}}' | grep kuma`
   - **Fix:** Deploy services with AutoKuma labels (see infrastructure label migration)

**Verify AutoKuma is working:**
```bash
# Should see successful sync messages every 60 seconds
sudo docker service logs platform_observability_autokuma --follow

# Look for:
# "Syncing monitors..."
# "Created monitor: <name>"
# "Updated monitor: <name>"
```

**Force immediate sync:**
```bash
# Restart AutoKuma to trigger immediate sync
sudo docker service update --force platform_observability_autokuma
```
