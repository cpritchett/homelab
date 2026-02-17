# Label Patterns Reference

Complete label configurations for the unified label-driven infrastructure approach. All service metadata is declared once in `deploy.labels`, read by three integrations:

1. **Homepage** — Dashboard display and widgets
2. **Caddy** (caddy-docker-proxy) — Reverse proxy and TLS certificates
3. **AutoKuma** — Uptime monitoring via Uptime Kuma

## Label Syntax

### Homepage Labels

```yaml
homepage.group: "<category>"        # Dashboard group name
homepage.name: "<display name>"     # Service display name
homepage.icon: "<icon>"             # Icon (filename or mdi-* prefix)
homepage.href: "<url>"              # Click-through URL
homepage.description: "<text>"      # Short description
homepage.widget.type: "<type>"      # Widget type (optional)
homepage.widget.url: "<api-url>"    # Widget API endpoint
homepage.widget.key: "<key>"        # Widget API key (use HOMEPAGE_VAR_*)
```

### Caddy Labels

```yaml
caddy: <hostname>                                        # Single-site mode
caddy.reverse_proxy: "{{upstreams <port>}}"             # Backend target
caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"  # DNS challenge TLS

# Numbered blocks (for multiple sites or ordering)
caddy_0: <hostname>
caddy_0.reverse_proxy: "<backend>"
caddy_0.tls: internal
```

### AutoKuma Labels

```yaml
kuma.<monitor-id>.<type>.<setting>: "value"
```

- `<monitor-id>`: Unique identifier (e.g., `komodo`, `caddy`, `homepage`)
- `<type>`: Monitor type (`http`, `port`, `docker`, `dns`, `keyword`)
- `<setting>`: Configuration key (`name`, `url`, `interval`, etc.)

## Infrastructure Tier Examples

### Komodo Orchestration

```yaml
services:
  core:
    image: ghcr.io/moghtech/komodo-core:2-dev
    deploy:
      labels:
        homepage.group: "Infrastructure"
        homepage.name: "Komodo"
        homepage.icon: "mdi-docker"
        homepage.href: "https://komodo.in.hypyr.space"
        homepage.description: "Infrastructure orchestration"
        homepage.widget.type: "komodo"
        homepage.widget.url: "https://komodo.in.hypyr.space"
        homepage.widget.key: "{{HOMEPAGE_VAR_KOMODO_API_KEY}}"

        caddy_0: komodo.in.hypyr.space
        caddy_0.reverse_proxy: core:30160
        caddy_0.tls: internal

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

        caddy: op-connect.in.hypyr.space
        caddy.reverse_proxy: "op-connect-api:8080"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

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
        homepage.group: "Infrastructure"
        homepage.name: "Caddy"
        homepage.icon: "caddy.png"
        homepage.href: "https://barbary.in.hypyr.space"
        homepage.description: "Reverse proxy & TLS"

        # Caddy doesn't proxy itself — no caddy labels

        kuma.caddy.http.name: "Caddy Reverse Proxy"
        kuma.caddy.http.url: "https://home.in.hypyr.space"
        kuma.caddy.http.interval: "60"
        kuma.caddy.http.maxretries: "3"
```

## Platform Tier Examples

### Authentik SSO

```yaml
services:
  authentik-server:
    image: ghcr.io/goauthentik/server:2025.12.2
    deploy:
      labels:
        homepage.group: "Platform"
        homepage.name: "Authentik"
        homepage.icon: "authentik.png"
        homepage.href: "https://auth.in.hypyr.space"
        homepage.description: "SSO & Authentication"
        homepage.widget.type: "authentik"
        homepage.widget.url: "https://auth.in.hypyr.space"
        homepage.widget.key: "{{HOMEPAGE_VAR_AUTHENTIK_API_KEY}}"

        caddy: auth.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 9000}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        kuma.authentik.http.name: "Authentik SSO"
        kuma.authentik.http.url: "https://auth.in.hypyr.space"
        kuma.authentik.http.interval: "60"
        kuma.authentik.http.maxretries: "3"
        kuma.authentik.http.accepted_statuscodes: "200-299,301,302"
```

### Uptime Kuma / Homepage / Loki / Cloudflare Tunnel

```yaml
# Uptime Kuma
kuma.uptime-kuma.http.name: "Uptime Kuma"
kuma.uptime-kuma.http.url: "https://status.in.hypyr.space"
kuma.uptime-kuma.http.interval: "60"

# Homepage
kuma.homepage.http.name: "Homepage Dashboard"
kuma.homepage.http.url: "https://home.in.hypyr.space"
kuma.homepage.http.interval: "60"
kuma.homepage.http.keyword: "Homelab"

# Loki
kuma.loki.http.name: "Loki"
kuma.loki.http.url: "http://loki:3100/ready"
kuma.loki.http.interval: "60"

# Cloudflare Tunnel
kuma.cloudflared.http.name: "Cloudflare Tunnel"
kuma.cloudflared.http.url: "http://cloudflared:2000/ready"
kuma.cloudflared.http.interval: "60"
```

## Internal Service Examples

### PostgreSQL (TCP Port Monitor)

```yaml
kuma.postgres.port.name: "PostgreSQL Database"
kuma.postgres.port.hostname: "postgres"
kuma.postgres.port.port: "5432"
kuma.postgres.port.interval: "60"
```

### Redis (TCP Port Monitor)

```yaml
kuma.redis.port.name: "Redis Cache"
kuma.redis.port.hostname: "redis"
kuma.redis.port.port: "6379"
kuma.redis.port.interval: "60"
```

### Background Worker (Docker Container Monitor)

```yaml
kuma.worker.docker.name: "Background Worker"
kuma.worker.docker.docker_container: "worker"
kuma.worker.docker.docker_host: "1"
kuma.worker.docker.interval: "60"
```

## Monitor Type Reference

### HTTP/HTTPS

```yaml
kuma.<id>.http.name: "Service Name"
kuma.<id>.http.url: "https://example.com"
kuma.<id>.http.method: "GET"                    # Optional
kuma.<id>.http.interval: "60"
kuma.<id>.http.maxretries: "3"
kuma.<id>.http.retryInterval: "60"
kuma.<id>.http.accepted_statuscodes: "200-299"
```

### TCP Port

```yaml
kuma.<id>.port.name: "PostgreSQL"
kuma.<id>.port.hostname: "postgres"
kuma.<id>.port.port: "5432"
kuma.<id>.port.interval: "60"
```

### Docker Container

```yaml
kuma.<id>.docker.name: "Container Name"
kuma.<id>.docker.docker_container: "redis"
kuma.<id>.docker.docker_host: "1"
kuma.<id>.docker.interval: "60"
```

### DNS

```yaml
kuma.<id>.dns.name: "DNS Resolution Check"
kuma.<id>.dns.hostname: "komodo.in.hypyr.space"
kuma.<id>.dns.resolver_server: "1.1.1.1"
kuma.<id>.dns.dns_resolve_type: "A"
kuma.<id>.dns.interval: "300"
```

### Keyword

```yaml
kuma.<id>.keyword.name: "API Health Check"
kuma.<id>.keyword.url: "https://api.example.com/health"
kuma.<id>.keyword.keyword: "\"status\":\"ok\""
kuma.<id>.keyword.interval: "60"
```

## Label Groups by Purpose

| Service Type | Homepage | Caddy | AutoKuma |
|---|---|---|---|
| Public web UI | `homepage.*` | `caddy.*` | `kuma.*.http.*` |
| Internal API | `homepage.*` + widget | — | `kuma.*.http.*` (health endpoint) |
| Database/cache | `homepage.*` (basic) | — | `kuma.*.port.*` |
| Background worker | `homepage.*` (basic) | — | `kuma.*.docker.*` |

## Best Practices

1. **Consistent naming** — use the same base name across all label sets
2. **Group organization** — Infrastructure, Platform, Observability, Applications
3. **Widgets only where useful** — services with API data (Komodo, Authentik, Grafana)
4. **Internal URLs for monitoring** — faster, more reliable than going through ingress
5. **Appropriate intervals** — critical: 60s, non-critical: 300s, external APIs: 300-600s
6. **Configure retries** — prevent false positives with `maxretries: "3"` and `retryInterval: "60"`
7. **Notifications** — reference by ID: `kuma.<id>.http.notificationIDList: "1,2,3"`

## References

- [AutoKuma GitHub](https://github.com/BigBoot/AutoKuma)
- [Homepage Documentation](https://gethomepage.dev/)
- [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy)
