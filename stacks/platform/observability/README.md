# Observability Stack

Combined stack for homelab observability and monitoring services.

## Services

### Homepage Dashboard
- **URL**: https://home.in.hypyr.space
- **Purpose**: Centralized dashboard for monitoring all homelab services
- **Integration**: Docker socket proxy for service discovery
- **Config**: `/mnt/apps01/appdata/homepage/config/`

### Uptime Kuma
- **URL**: https://status.in.hypyr.space
- **Purpose**: Uptime monitoring and status page
- **Data**: `/mnt/apps01/appdata/uptime-kuma/`

### Docker Socket Proxy
- **Purpose**: Secure, read-only access to Docker API for Homepage
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

### Configure Homepage
1. Access https://home.in.hypyr.space
2. Edit config files in Komodo UI or via SSH
3. Homepage auto-reloads on config changes

### Configure Uptime Kuma
1. Access https://status.in.hypyr.space
2. Complete initial setup (create admin user)
3. Add monitors:
   - Komodo: https://komodo.in.hypyr.space
   - 1Password Connect: http://op-connect-api:8080/health
   - Homepage: https://home.in.hypyr.space

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
