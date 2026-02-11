# Complete Label Examples - Homepage + Caddy + AutoKuma

This document shows complete label configurations for common service patterns, demonstrating the unified label-driven infrastructure approach.

## Pattern: Single Source of Truth

All service metadata is declared once in `deploy.labels`. Three integrations read from these labels:

1. **Homepage** - Dashboard display and widgets
2. **Caddy** - Reverse proxy and TLS certificates
3. **AutoKuma** - Uptime monitoring

This is equivalent to Kubernetes annotations for ingress-nginx, cert-manager, and external-dns.

## Infrastructure Tier Examples

### Komodo Orchestration

```yaml
services:
  core:
    image: ghcr.io/moghtech/komodo-core:2-dev
    deploy:
      labels:
        # Homepage: Infrastructure dashboard
        homepage.group: "Infrastructure"
        homepage.name: "Komodo"
        homepage.icon: "mdi-docker"
        homepage.href: "https://komodo.in.hypyr.space"
        homepage.description: "Infrastructure orchestration"
        homepage.widget.type: "komodo"
        homepage.widget.url: "https://komodo.in.hypyr.space"
        homepage.widget.key: "{{HOMEPAGE_VAR_KOMODO_API_KEY}}"

        # Caddy: Reverse proxy (internal TLS)
        caddy_0: komodo.in.hypyr.space
        caddy_0.reverse_proxy: core:30160
        caddy_0.tls: internal

        # AutoKuma: Uptime monitoring
        kuma.komodo.http.name: "Komodo UI"
        kuma.komodo.http.url: "https://komodo.in.hypyr.space"
        kuma.komodo.http.interval: "60"
        kuma.komodo.http.maxretries: "3"
```

### 1Password Connect API

```yaml
services:
  op-connect-api:
    image: 1password/connect-api:1.7.3
    deploy:
      labels:
        # Homepage: Infrastructure dashboard
        homepage.group: "Infrastructure"
        homepage.name: "1Password Connect"
        homepage.icon: "1password.png"
        homepage.href: "http://op-connect-api:8080"
        homepage.description: "Secrets management"
        homepage.widget.type: "customapi"
        homepage.widget.url: "http://op-connect-api:8080/health"
        homepage.widget.mappings.0.field: "name"
        homepage.widget.mappings.0.label: "Service"
        homepage.widget.mappings.1.field: "version"
        homepage.widget.mappings.1.label: "Version"

        # Caddy: Reverse proxy (optional - usually internal only)
        caddy: op-connect.in.hypyr.space
        caddy.reverse_proxy: "op-connect-api:8080"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: Internal health check
        kuma.op-connect.http.name: "1Password Connect API"
        kuma.op-connect.http.url: "http://op-connect-api:8080/health"
        kuma.op-connect.http.interval: "60"
        kuma.op-connect.http.maxretries: "5"
```

### Caddy Reverse Proxy

```yaml
services:
  caddy:
    image: ghcr.io/cpritchett/caddy-labels:latest
    deploy:
      labels:
        # Homepage: Infrastructure dashboard
        homepage.group: "Infrastructure"
        homepage.name: "Caddy"
        homepage.icon: "caddy.png"
        homepage.href: "https://barbary.in.hypyr.space"
        homepage.description: "Reverse proxy & TLS"

        # AutoKuma: Monitor via proxied service
        kuma.caddy.http.name: "Caddy Reverse Proxy"
        kuma.caddy.http.url: "https://home.in.hypyr.space"
        kuma.caddy.http.interval: "60"
        kuma.caddy.http.maxretries: "3"

        # Note: Caddy doesn't proxy itself, so no caddy labels
```

## Platform Tier Examples

### Authentik SSO

```yaml
services:
  authentik-server:
    image: ghcr.io/goauthentik/server:2025.12.2
    deploy:
      labels:
        # Homepage: Platform dashboard
        homepage.group: "Platform"
        homepage.name: "Authentik"
        homepage.icon: "authentik.png"
        homepage.href: "https://auth.in.hypyr.space"
        homepage.description: "SSO & Authentication"
        homepage.widget.type: "authentik"
        homepage.widget.url: "https://auth.in.hypyr.space"
        homepage.widget.key: "{{HOMEPAGE_VAR_AUTHENTIK_API_KEY}}"

        # Caddy: Public reverse proxy
        caddy: auth.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 9000}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: External monitoring (accepts redirects)
        kuma.authentik.http.name: "Authentik SSO"
        kuma.authentik.http.url: "https://auth.in.hypyr.space"
        kuma.authentik.http.interval: "60"
        kuma.authentik.http.maxretries: "3"
        kuma.authentik.http.accepted_statuscodes: "200-299,301,302"
```

### Uptime Kuma

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:2.0.2
    deploy:
      labels:
        # Homepage: Observability dashboard
        homepage.group: "Observability"
        homepage.name: "Uptime Kuma"
        homepage.icon: "uptime-kuma.png"
        homepage.href: "https://status.in.hypyr.space"
        homepage.description: "Uptime monitoring"
        homepage.widget.type: "uptimekuma"
        homepage.widget.url: "https://status.in.hypyr.space"
        homepage.widget.slug: "homelab"

        # Caddy: Public reverse proxy
        caddy: status.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 3001}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: Self-monitoring
        kuma.uptime-kuma.http.name: "Uptime Kuma"
        kuma.uptime-kuma.http.url: "https://status.in.hypyr.space"
        kuma.uptime-kuma.http.interval: "60"
```

### Homepage Dashboard

```yaml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:v0.9.10
    deploy:
      labels:
        # Homepage: Self-reference
        homepage.group: "Observability"
        homepage.name: "Homepage"
        homepage.icon: "homepage.png"
        homepage.href: "https://home.in.hypyr.space"
        homepage.description: "Homelab dashboard"

        # Caddy: Public reverse proxy
        caddy: home.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 3000}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: External monitoring
        kuma.homepage.http.name: "Homepage Dashboard"
        kuma.homepage.http.url: "https://home.in.hypyr.space"
        kuma.homepage.http.interval: "60"
        kuma.homepage.http.keyword: "Homelab"
```

### Loki Log Aggregation

```yaml
services:
  loki:
    image: grafana/loki:3.3.2
    deploy:
      labels:
        # Homepage: Monitoring dashboard
        homepage.group: "Monitoring"
        homepage.name: "Loki"
        homepage.icon: "loki.png"
        homepage.href: "https://loki.in.hypyr.space"
        homepage.description: "Log aggregation"

        # Caddy: Public reverse proxy
        caddy: loki.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 3100}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: Internal health check
        kuma.loki.http.name: "Loki"
        kuma.loki.http.url: "http://loki:3100/ready"
        kuma.loki.http.interval: "60"
        kuma.loki.http.maxretries: "3"
```

### Cloudflare Tunnel

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:2024.10.1
    deploy:
      labels:
        # Homepage: Infrastructure dashboard
        homepage.group: "Infrastructure"
        homepage.name: "Cloudflare Tunnel"
        homepage.icon: "cloudflare.png"
        homepage.href: "https://dash.cloudflare.com"
        homepage.description: "External ingress tunnel"

        # No Caddy labels (tunnel routes TO Caddy, not through it)

        # AutoKuma: Metrics endpoint monitoring
        kuma.cloudflared.http.name: "Cloudflare Tunnel"
        kuma.cloudflared.http.url: "http://cloudflared:2000/ready"
        kuma.cloudflared.http.interval: "60"
        kuma.cloudflared.http.maxretries: "3"
```

## Application Tier Examples

### Grafana

```yaml
services:
  grafana:
    image: grafana/grafana:latest
    deploy:
      labels:
        # Homepage: Monitoring dashboard
        homepage.group: "Monitoring"
        homepage.name: "Grafana"
        homepage.icon: "grafana.png"
        homepage.href: "https://grafana.in.hypyr.space"
        homepage.description: "Metrics visualization"
        homepage.widget.type: "grafana"
        homepage.widget.url: "https://grafana.in.hypyr.space"
        homepage.widget.username: "{{HOMEPAGE_VAR_GRAFANA_USER}}"
        homepage.widget.password: "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}"

        # Caddy: Public reverse proxy
        caddy: grafana.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 3000}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: External monitoring
        kuma.grafana.http.name: "Grafana"
        kuma.grafana.http.url: "https://grafana.in.hypyr.space/api/health"
        kuma.grafana.http.interval: "60"
```

### Prometheus

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    deploy:
      labels:
        # Homepage: Monitoring dashboard
        homepage.group: "Monitoring"
        homepage.name: "Prometheus"
        homepage.icon: "prometheus.png"
        homepage.href: "https://prometheus.in.hypyr.space"
        homepage.description: "Metrics collection"
        homepage.widget.type: "prometheus"
        homepage.widget.url: "http://prometheus:9090"

        # Caddy: Public reverse proxy
        caddy: prometheus.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 9090}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma: Internal monitoring
        kuma.prometheus.http.name: "Prometheus"
        kuma.prometheus.http.url: "http://prometheus:9090/-/healthy"
        kuma.prometheus.http.interval: "60"
```

## Internal Service Examples

### PostgreSQL Database

```yaml
services:
  postgres:
    image: postgres:18
    deploy:
      labels:
        # Homepage: Internal service (no widget)
        homepage.group: "Platform"
        homepage.name: "PostgreSQL"
        homepage.icon: "postgres.png"
        homepage.description: "Database server"

        # No Caddy labels (internal only)

        # AutoKuma: TCP port monitoring
        kuma.postgres.port.name: "PostgreSQL Database"
        kuma.postgres.port.hostname: "postgres"
        kuma.postgres.port.port: "5432"
        kuma.postgres.port.interval: "60"
```

### Redis Cache

```yaml
services:
  redis:
    image: redis:8-alpine
    deploy:
      labels:
        # Homepage: Internal service
        homepage.group: "Platform"
        homepage.name: "Redis"
        homepage.icon: "redis.png"
        homepage.description: "Cache server"

        # No Caddy labels (internal only)

        # AutoKuma: TCP port monitoring
        kuma.redis.port.name: "Redis Cache"
        kuma.redis.port.hostname: "redis"
        kuma.redis.port.port: "6379"
        kuma.redis.port.interval: "60"
```

### Background Worker

```yaml
services:
  worker:
    image: myapp-worker:latest
    deploy:
      labels:
        # Homepage: Background service
        homepage.group: "Applications"
        homepage.name: "Background Worker"
        homepage.icon: "mdi-cog"
        homepage.description: "Job processing"

        # No Caddy labels (no HTTP endpoint)

        # AutoKuma: Docker container health
        kuma.worker.docker.name: "Background Worker"
        kuma.worker.docker.docker_container: "worker"
        kuma.worker.docker.docker_host: "1"
        kuma.worker.docker.interval: "60"
```

## Label Groups by Purpose

### Dashboard-Only (Internal Services)

Services that don't need external access but should appear in dashboard:

```yaml
homepage.group: "<category>"
homepage.name: "<name>"
homepage.icon: "<icon>"
homepage.description: "<description>"
```

### Public Web Services (Full Stack)

Services with web UIs accessible externally:

```yaml
# All three label sets
homepage.*
caddy.*
kuma.*.http.*
```

### API Services (Monitoring Focus)

Services with APIs but minimal UI:

```yaml
homepage.* (with widget)
caddy.* (if external access needed)
kuma.*.http.* (health endpoints)
```

### Infrastructure Services (Port Monitoring)

Databases, caches, message queues:

```yaml
homepage.* (basic info)
kuma.*.port.* (TCP checks)
```

## Best Practices

### 1. Consistent Naming

Use the same base name across all labels:

```yaml
homepage.name: "Authentik"
kuma.authentik.http.name: "Authentik SSO"
# Both refer to same service
```

### 2. Group Organization

Use consistent group names:
- **Infrastructure**: Core platform services (Komodo, Caddy, 1Password)
- **Platform**: Shared services (Authentik, Forgejo, Grafana)
- **Observability**: Monitoring/dashboards (Homepage, Uptime Kuma, Prometheus)
- **Applications**: End-user applications (Media, Home automation)

### 3. Widget Configuration

Only add widgets for services with useful APIs:
- ✅ Komodo (orchestration stats)
- ✅ Authentik (user counts)
- ✅ Uptime Kuma (status overview)
- ✅ Grafana (dashboard links)
- ❌ Static sites (no useful data)

### 4. Monitoring Granularity

Choose appropriate monitor types:
- **HTTP**: Web UIs and health endpoints
- **Port**: Databases and non-HTTP services
- **Docker**: Background workers
- **Keyword**: API responses needing validation

### 5. Internal vs External URLs

Prefer internal URLs for monitoring:

```yaml
# Good: Direct service check
kuma.db.port.hostname: "postgres"
kuma.api.http.url: "http://api:8080/health"

# Acceptable: External validation
kuma.app.http.url: "https://app.in.hypyr.space"
```

## Migration from Manual Config

If you have existing services in Homepage's `services.yaml`:

1. **Add labels** to service's `deploy.labels` section
2. **Redeploy** via Komodo to apply labels
3. **Wait 30-60 seconds** for Homepage to discover service
4. **Verify** service appears in Homepage UI
5. **Remove** manual entry from `services.yaml` (optional - both work)

Auto-discovered services override manual configuration.

## Troubleshooting

**Service not appearing in Homepage:**
- Check labels are under `deploy.labels`
- Verify Homepage can access Docker API
- Check Homepage logs: `docker service logs platform_observability_homepage`

**Monitor not created:**
- Ensure Uptime Kuma is initialized (admin account created)
- Check AutoKuma logs: `docker service logs platform_observability_autokuma`
- Verify kuma.* label syntax

**Caddy not proxying:**
- Verify service on `proxy_network`
- Check Caddy labels syntax
- Check Caddy logs: `docker service logs caddy_caddy`
