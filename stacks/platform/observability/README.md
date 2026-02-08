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
1. Access https://status.in.hypyr.space
2. Complete initial setup (create admin user)
3. **Important**: After creating admin account, AutoKuma will automatically connect
4. Monitors will be auto-created from Docker labels

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
