# AutoKuma Label Examples for Infrastructure Services

This document provides examples of adding AutoKuma monitoring labels to infrastructure and platform services.

## Label Pattern

```yaml
kuma.<monitor-id>.<type>.<setting>: "value"
```

- `<monitor-id>`: Unique identifier for the monitor (e.g., "komodo", "caddy", "homepage")
- `<type>`: Monitor type (http, port, docker, etc.)
- `<setting>`: Configuration key (name, url, interval, etc.)

## Infrastructure Tier Examples

### Komodo Core

```yaml
services:
  core:
    deploy:
      labels:
        # Caddy ingress
        caddy_0: komodo.in.hypyr.space
        caddy_0.reverse_proxy: core:30160
        caddy_0.tls: internal

        # AutoKuma HTTP monitor
        kuma.komodo.http.name: "Komodo UI"
        kuma.komodo.http.url: "https://komodo.in.hypyr.space"
        kuma.komodo.http.interval: "60"
        kuma.komodo.http.maxretries: "3"
```

### 1Password Connect API

```yaml
services:
  op-connect-api:
    deploy:
      labels:
        # Caddy ingress
        caddy: op-connect.in.hypyr.space
        caddy.reverse_proxy: "op-connect-api:8080"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma HTTP health check (internal)
        kuma.op-connect.http.name: "1Password Connect API"
        kuma.op-connect.http.url: "http://op-connect-api:8080/health"
        kuma.op-connect.http.interval: "60"
        kuma.op-connect.http.maxretries: "5"
```

### Caddy Reverse Proxy

```yaml
services:
  caddy:
    deploy:
      labels:
        # AutoKuma HTTP monitor (via proxied service)
        kuma.caddy.http.name: "Caddy Reverse Proxy"
        kuma.caddy.http.url: "https://home.in.hypyr.space"
        kuma.caddy.http.interval: "60"
        kuma.caddy.http.maxretries: "3"
```

## Platform Tier Examples

### Homepage Dashboard

```yaml
services:
  homepage:
    deploy:
      labels:
        # Caddy ingress
        caddy: home.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 3000}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma HTTP monitor
        kuma.homepage.http.name: "Homepage Dashboard"
        kuma.homepage.http.url: "https://home.in.hypyr.space"
        kuma.homepage.http.interval: "60"
        kuma.homepage.http.keyword: "Homelab"  # Optional: verify page content
```

### Authentik SSO

```yaml
services:
  authentik-server:
    deploy:
      labels:
        # Caddy ingress
        caddy: auth.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 9000}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma HTTP monitor
        kuma.authentik.http.name: "Authentik SSO"
        kuma.authentik.http.url: "https://auth.in.hypyr.space"
        kuma.authentik.http.interval: "60"
        kuma.authentik.http.accepted_statuscodes: "200-299,301,302"  # Allow redirects
```

## Monitor Type Examples

### HTTP/HTTPS Monitoring

```yaml
kuma.service.http.name: "Service Name"
kuma.service.http.url: "https://example.com"
kuma.service.http.method: "GET"  # Optional: GET, POST, PUT, etc.
kuma.service.http.interval: "60"
kuma.service.http.maxretries: "3"
kuma.service.http.retryInterval: "60"
kuma.service.http.accepted_statuscodes: "200-299"
```

### TCP Port Monitoring

```yaml
kuma.db.port.name: "PostgreSQL"
kuma.db.port.hostname: "postgres"
kuma.db.port.port: "5432"
kuma.db.port.interval: "60"
```

### Docker Container Monitoring

```yaml
kuma.container.docker.name: "Redis Container"
kuma.container.docker.docker_container: "redis"
kuma.container.docker.docker_host: "1"  # Uses AutoKuma's Docker connection
kuma.container.docker.interval: "60"
```

### DNS Monitoring

```yaml
kuma.dns.dns.name: "DNS Resolution Check"
kuma.dns.dns.hostname: "komodo.in.hypyr.space"
kuma.dns.dns.resolver_server: "1.1.1.1"
kuma.dns.dns.dns_resolve_type: "A"
kuma.dns.dns.interval: "300"  # Every 5 minutes
```

### Keyword Monitoring

```yaml
kuma.api.keyword.name: "API Health Check"
kuma.api.keyword.url: "https://api.example.com/health"
kuma.api.keyword.keyword: "\"status\":\"ok\""  # Search response for keyword
kuma.api.keyword.interval: "60"
```

## Best Practices

1. **Use Descriptive Names**: Make monitor names clear and consistent
   ```yaml
   kuma.service.http.name: "Service Name - Environment"
   ```

2. **Set Appropriate Intervals**: Don't over-poll
   - Critical services: 60 seconds
   - Non-critical: 300 seconds (5 minutes)
   - External APIs: 300-600 seconds

3. **Configure Retry Logic**: Prevent false positives
   ```yaml
   kuma.service.http.maxretries: "3"
   kuma.service.http.retryInterval: "60"
   ```

4. **Use Internal URLs When Possible**: Faster, more reliable
   ```yaml
   # Good: Internal service discovery
   kuma.op-connect.http.url: "http://op-connect-api:8080/health"

   # Okay: External via ingress
   kuma.komodo.http.url: "https://komodo.in.hypyr.space"
   ```

5. **Group Related Monitors**: Use consistent naming prefixes
   ```yaml
   kuma.authentik-server.http.name: "Authentik - Server"
   kuma.authentik-worker.docker.name: "Authentik - Worker"
   kuma.authentik-db.port.name: "Authentik - PostgreSQL"
   ```

## Notifications

Configure notifications in Uptime Kuma UI, then reference by ID:

```yaml
kuma.critical.http.notificationIDList: "1,2,3"  # Email, Slack, Discord
```

## Applying Labels

After adding labels to compose files:

1. **Commit changes** to Git repository
2. **Redeploy stack** via Komodo UI
3. **Wait 60 seconds** for AutoKuma to scan and create monitors
4. **Verify in Uptime Kuma** - monitors appear with "autokuma" tag

## Removing Monitors

AutoKuma can optionally remove monitors when labels are removed. By default, monitors persist even if the service is deleted. Configure via environment variable:

```yaml
AUTOKUMA__AUTO_DELETE: "true"  # Delete monitors when labels disappear
```

## Troubleshooting

**Monitors not appearing:**
1. Check AutoKuma logs: `docker service logs platform_observability_autokuma`
2. Verify labels are under `deploy.labels` (not container labels)
3. Wait for next sync cycle (60 seconds)
4. Check Uptime Kuma API is accessible

**Duplicate monitors:**
- Ensure monitor IDs are unique across all services
- AutoKuma uses `<monitor-id>` as the identifier

**Monitor updates not applying:**
- AutoKuma syncs every 60 seconds
- Changes to labels require stack redeploy
- Check AutoKuma logs for sync errors

## References

- [AutoKuma GitHub](https://github.com/BigBoot/AutoKuma)
- [Uptime Kuma Wiki - Docker Monitoring](https://github.com/louislam/uptime-kuma/wiki/How-to-Monitor-Docker-Containers)
- [Monitor Type Documentation](https://github.com/BigBoot/AutoKuma#monitor-types)
