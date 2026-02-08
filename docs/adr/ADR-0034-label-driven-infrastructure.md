# ADR-0034: Label-Driven Infrastructure Pattern for Docker Swarm

**Status:** Accepted
**Date:** 2026-02-08
**Authors:** System Architect
**Supersedes:** None
**Relates to:** ADR-0033 (TrueNAS Swarm Migration), ADR-0032 (1Password Connect)

## Context

Docker Swarm services deployed on TrueNAS Scale require:
1. **Reverse proxy ingress** for external access with automatic TLS certificates
2. **Uptime monitoring** to track service health and availability
3. **Service discovery** so ingress and monitoring systems can find services automatically

Traditional approaches require:
- Manual configuration files (Caddyfile, nginx.conf, traefik.yml)
- Manual monitor creation in monitoring UIs
- Configuration drift between compose files and supporting services
- Multiple sources of truth for service metadata

Modern cloud-native patterns use **label-based service discovery** where:
- Service metadata is declared once in the compose file via labels
- Supporting services (reverse proxy, monitoring) read labels via Docker API
- Single source of truth eliminates configuration drift
- Infrastructure as Code with self-documenting service requirements

## Decision

**MANDATORY: All Docker Swarm services MUST use label-driven patterns for ALL supporting infrastructure.**

**Principle**: If a tool supports Docker labels for configuration, labels MUST be used instead of manual configuration files. This is equivalent to Kubernetes annotations being the standard for ingress, cert-manager, external-dns, etc.

### 1. Reverse Proxy Ingress via Caddy Labels

**Requirement**: All externally-accessible services MUST declare Caddy labels under `deploy.labels`.

**Caddy Labels Pattern**:
```yaml
services:
  app:
    deploy:
      labels:
        caddy: <domain>
        caddy.reverse_proxy: "{{upstreams <port>}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
```

**Required Labels**:
- `caddy: <domain>` - Domain name for the service (e.g., `app.in.hypyr.space`)
- `caddy.reverse_proxy` - Upstream target using Caddy template syntax
- `caddy.tls.dns` - DNS-01 ACME challenge for wildcard certificates

**Rationale**:
- Caddy auto-discovers services via Docker API
- TLS certificates obtained and renewed automatically
- No manual Caddyfile required
- Service metadata lives with the service definition

### 2. Dashboard Display via Homepage Labels

**Requirement**: All services MUST declare Homepage labels under `deploy.labels` for dashboard display.

**Homepage Labels Pattern**:
```yaml
services:
  app:
    deploy:
      labels:
        homepage.group: "<category>"
        homepage.name: "<display-name>"
        homepage.icon: "<icon-file-or-mdi>"
        homepage.href: "<service-url>"
        homepage.description: "<short-description>"
```

**Example - Basic Service**:
```yaml
services:
  authentik-server:
    deploy:
      labels:
        homepage.group: "Platform"
        homepage.name: "Authentik"
        homepage.icon: "authentik.png"
        homepage.href: "https://auth.in.hypyr.space"
        homepage.description: "SSO & Authentication"
```

**Example - With Widget**:
```yaml
services:
  komodo-core:
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
```

**Widget Types**: Homepage supports 100+ widget types. Common examples:
- `authentik` - Authentik SSO stats
- `komodo` - Komodo orchestration stats
- `uptimekuma` - Uptime Kuma status
- `prometheus` - Prometheus metrics
- `grafana` - Grafana dashboards
- `customapi` - Custom API endpoints

**Rationale**:
- Homepage auto-discovers services via Docker API
- No manual `services.yaml` configuration needed
- Service metadata lives with the service definition
- Dashboard updates automatically when services deploy

### 3. Uptime Monitoring via AutoKuma Labels

**Requirement**: All services MUST declare AutoKuma monitoring labels under `deploy.labels`.

**AutoKuma Labels Pattern**:
```yaml
services:
  app:
    deploy:
      labels:
        kuma.<monitor-id>.<type>.<setting>: "value"
```

**Example - HTTP Monitor**:
```yaml
services:
  app:
    deploy:
      labels:
        kuma.app.http.name: "Application Name"
        kuma.app.http.url: "https://app.in.hypyr.space"
        kuma.app.http.interval: "60"
        kuma.app.http.maxretries: "3"
```

**Example - Internal Service Monitor**:
```yaml
services:
  database:
    deploy:
      labels:
        kuma.db.port.name: "PostgreSQL Database"
        kuma.db.port.hostname: "postgres"
        kuma.db.port.port: "5432"
        kuma.db.port.interval: "60"
```

**Monitor Types**:
- `http` / `https` - HTTP(S) endpoint checks
- `port` - TCP port availability
- `docker` - Container health status
- `keyword` - HTTP response content validation
- `dns` - DNS record verification
- `ping` - ICMP reachability

**Rationale**:
- AutoKuma auto-creates monitors via Uptime Kuma API
- Monitors update when labels change
- No manual monitor configuration in UI
- Infrastructure health monitoring as code

### 4. Future Integration Pattern

**MANDATORY**: When adding ANY new tool that supports Docker label-based configuration, labels MUST be used instead of manual configuration files.

**Examples of tools that support labels**:
- Traefik (ingress)
- Caddy (ingress) ✓ Already implemented
- Homepage (dashboard) ✓ Already implemented
- AutoKuma (monitoring) ✓ Already implemented
- Diun (image update notifications)
- Shepherd (automated updates)
- Ofelia (cron scheduling)

**Decision Process for New Tools**:
1. Check if tool supports Docker labels/annotations
2. If YES → Use labels as primary configuration method
3. If NO → Evaluate if tool is necessary or find alternative

**Rationale**:
- Consistency with Kubernetes annotation pattern
- Single source of truth for service metadata
- Infrastructure as Code principles
- Eliminates configuration drift

### 5. Label Placement Rules

**MANDATORY**: Labels MUST be placed under `deploy.labels`, NOT at the container level.

**Correct** (Swarm service labels):
```yaml
services:
  app:
    deploy:
      labels:
        caddy: app.in.hypyr.space
        kuma.app.http.url: "https://app.in.hypyr.space"
```

**Incorrect** (container labels - will not work):
```yaml
services:
  app:
    labels:  # ❌ Wrong - these are container labels
      caddy: app.in.hypyr.space
```

**Rationale**:
- Docker Swarm service labels are visible to label consumers (Caddy, AutoKuma)
- Container labels are only visible on the running container, not at service level
- Caddy and AutoKuma query the Docker API at the service level

### 6. Network Requirements

**MANDATORY**: Services with Caddy labels MUST attach to `proxy_network`.

```yaml
services:
  app:
    deploy:
      labels:
        caddy: app.in.hypyr.space
    networks:
      - proxy_network  # Required for Caddy ingress

networks:
  proxy_network:
    external: true
```

**Rationale**:
- Caddy reverse proxy must be able to reach upstream services
- `proxy_network` is the shared overlay network for ingress

### 7. Internal vs External Monitoring

**Best Practice**: Use internal service names for monitoring when possible.

**Preferred** (internal monitoring):
```yaml
kuma.api.http.name: "API Health Check"
kuma.api.http.url: "http://api:8080/health"  # Internal service discovery
```

**Alternative** (external monitoring):
```yaml
kuma.api.http.name: "API Health Check"
kuma.api.http.url: "https://api.in.hypyr.space/health"  # Via ingress
```

**Rationale**:
- Internal monitoring is faster and more reliable
- Doesn't depend on external DNS, TLS, or ingress
- Tests service health directly, not just ingress path

### 8. Governance Requirements

**REQUIRED for all new services**:
1. ✅ Homepage labels for dashboard display
2. ✅ Caddy labels for external access (if publicly accessible)
3. ✅ AutoKuma labels for monitoring
4. ✅ Labels under `deploy.labels` section
5. ✅ Service attached to `proxy_network` if publicly accessible
6. ✅ Descriptive names matching service purpose across all labels

**REQUIRED for stack documentation**:
- README.md must document expected external URLs
- README.md must list all monitors that will be auto-created
- Label examples must be included for each service type

**REQUIRED for code review**:
- All PRs adding new services must include Homepage labels
- All PRs adding new services must include Caddy labels (if publicly accessible)
- All PRs adding new services must include AutoKuma labels
- Label placement must be validated (under `deploy.labels`)
- If adding a new tool, verify label-based config is used if available

## Implementation

### Infrastructure Tier (Bootstrap)

Services deployed via `scripts/truenas-init-bootstrap.sh`:

**Caddy** (stacks/infrastructure/caddy-compose.yaml):
- Runs ghcr.io/cpritchett/caddy-labels:latest with Docker integration
- Discovers services with `caddy` labels via Docker socket proxy
- Auto-generates reverse proxy configuration
- Obtains wildcard TLS certificates via Cloudflare DNS-01

**Example - Komodo (Complete Labels)**:
```yaml
services:
  core:
    deploy:
      labels:
        # Caddy ingress
        caddy_0: komodo.in.hypyr.space
        caddy_0.reverse_proxy: core:30160
        caddy_0.tls: internal

        # Homepage dashboard
        homepage.group: "Infrastructure"
        homepage.name: "Komodo"
        homepage.icon: "mdi-docker"
        homepage.href: "https://komodo.in.hypyr.space"
        homepage.description: "Infrastructure orchestration"
        homepage.widget.type: "komodo"
        homepage.widget.url: "https://komodo.in.hypyr.space"
        homepage.widget.key: "{{HOMEPAGE_VAR_KOMODO_API_KEY}}"

        # AutoKuma monitoring
        kuma.komodo.http.name: "Komodo UI"
        kuma.komodo.http.url: "https://komodo.in.hypyr.space"
        kuma.komodo.http.interval: "60"
```

### Platform Tier (Komodo-Managed)

Services deployed via Komodo UI from Git repository.

**Homepage** (stacks/platform/observability/compose.yaml):
- Runs ghcr.io/gethomepage/homepage:v0.9.10
- Discovers services with `homepage.*` labels via Docker socket proxy
- Auto-populates dashboard with discovered services
- No manual services.yaml configuration needed

**AutoKuma** (stacks/platform/observability/compose.yaml):
- Runs ghcr.io/bigboot/autokuma:latest
- Discovers services with `kuma.*` labels via Docker socket proxy
- Auto-creates/updates monitors in Uptime Kuma via API
- Tags all auto-created monitors with "autokuma"

**Example - Authentik (Complete Labels)**:
```yaml
services:
  authentik-server:
    deploy:
      labels:
        # Caddy ingress
        caddy: auth.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 9000}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # Homepage dashboard
        homepage.group: "Platform"
        homepage.name: "Authentik"
        homepage.icon: "authentik.png"
        homepage.href: "https://auth.in.hypyr.space"
        homepage.description: "SSO & Authentication"
        homepage.widget.type: "authentik"
        homepage.widget.url: "https://auth.in.hypyr.space"
        homepage.widget.key: "{{HOMEPAGE_VAR_AUTHENTIK_API_KEY}}"

        # AutoKuma monitoring
        kuma.authentik.http.name: "Authentik SSO"
        kuma.authentik.http.url: "https://auth.in.hypyr.space"
        kuma.authentik.http.interval: "60"
        kuma.authentik.http.accepted_statuscodes: "200-299,301,302"
```

### Docker Socket Proxy Security

**MANDATORY**: Caddy and AutoKuma MUST NOT have direct Docker socket access.

Access to Docker API is mediated via **Docker Socket Proxy** with read-only permissions:

```yaml
services:
  docker-socket-proxy:
    image: ghcr.io/tecnativa/docker-socket-proxy:latest
    environment:
      CONTAINERS: '1'
      SERVICES: '1'
      TASKS: '1'
      NETWORKS: '1'
      NODES: '1'
      INFO: '1'
      VERSION: '1'
      PING: '1'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

**Rationale**:
- Least privilege access to Docker API
- No write operations allowed
- Compromised reverse proxy or monitoring cannot manipulate containers

## Template for New Services

```yaml
services:
  myapp:
    image: myapp:latest
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
      labels:
        # Homepage dashboard (required)
        homepage.group: "Applications"
        homepage.name: "My Application"
        homepage.icon: "myapp.png"
        homepage.href: "https://myapp.in.hypyr.space"
        homepage.description: "Short description of service"
        # Optional: Add widget if service has API
        # homepage.widget.type: "customapi"
        # homepage.widget.url: "https://myapp.in.hypyr.space/api"

        # Caddy reverse proxy (required if publicly accessible)
        caddy: myapp.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 8080}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma monitoring (required)
        kuma.myapp.http.name: "My Application"
        kuma.myapp.http.url: "https://myapp.in.hypyr.space"
        kuma.myapp.http.interval: "60"
        kuma.myapp.http.maxretries: "3"
        kuma.myapp.http.retryInterval: "60"

    environment:
      TZ: America/Chicago

    volumes:
      - /mnt/apps01/appdata/myapp:/data

    networks:
      - proxy_network  # Required for Caddy ingress
      - myapp_internal  # Optional internal network

    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  proxy_network:
    external: true
  myapp_internal:
    driver: overlay
```

## Consequences

### Positive

✅ **Single Source of Truth**: Service metadata lives with the service definition
✅ **Automatic Service Discovery**: No manual configuration of reverse proxy, dashboard, or monitoring
✅ **Self-Documenting**: Labels describe service requirements declaratively
✅ **Reduced Toil**: No manual Caddyfile, services.yaml, or monitor creation
✅ **Configuration Drift Prevention**: Labels ensure consistency across all infrastructure
✅ **Code Review Friendly**: Labels are visible in compose file diffs
✅ **Infrastructure as Code**: All service metadata version-controlled with the service
✅ **Kubernetes-Like Pattern**: Familiar to anyone who's worked with k8s annotations

### Negative

⚠️ **Label Syntax Learning Curve**: Team must learn Caddy and AutoKuma label formats
⚠️ **Label Placement Critical**: Incorrect placement (`labels:` vs `deploy.labels:`) causes silent failures
⚠️ **Docker Socket Access Required**: Caddy and AutoKuma need read access to Docker API
⚠️ **Limited Validation**: Docker Compose doesn't validate label syntax
⚠️ **Debugging Complexity**: Need to check logs of Caddy/AutoKuma for label parsing errors

### Neutral

📝 **Pattern Consistency**: All services follow same labeling convention
📝 **Tool-Specific Syntax**: Label format depends on Caddy/AutoKuma expectations
📝 **Governance Enforcement**: Requires code review to ensure labels are present

## Validation Rules

### Pre-Deployment Checklist

Before deploying any stack, validate:

- [ ] Service has Caddy labels (if publicly accessible)
- [ ] Service has AutoKuma labels
- [ ] Labels are under `deploy.labels` (NOT `labels`)
- [ ] Service is on `proxy_network` (if using Caddy)
- [ ] Monitor ID is unique across all services
- [ ] Monitor name is descriptive and follows naming convention
- [ ] Internal service names used for monitoring when possible
- [ ] README documents expected URLs and monitors

### Post-Deployment Verification

After deploying a stack:

1. **Verify Caddy discovered service**:
   ```bash
   docker service logs caddy_caddy | grep <domain>
   curl -I https://<domain>
   ```

2. **Verify AutoKuma created monitor**:
   ```bash
   docker service logs platform_observability_autokuma | grep <monitor-id>
   # Check Uptime Kuma UI for monitor with "autokuma" tag
   ```

3. **Verify labels applied to service**:
   ```bash
   docker service inspect <service> --format '{{json .Spec.Labels}}' | jq .
   ```

## Migration Path

### Existing Services Without Labels

1. **Add labels** to compose file under `deploy.labels`
2. **Commit changes** to repository
3. **Redeploy via Komodo** to apply new labels
4. **Verify** Caddy and AutoKuma detect the changes
5. **Remove manual configuration** (if any existed)

### Future Services

All new services MUST include labels from initial commit. Code review will enforce this requirement.

## References

- [Caddy Docker Proxy Plugin](https://github.com/lucaslorentz/caddy-docker-proxy)
- [Homepage Docker Configuration](https://gethomepage.dev/configs/docker/)
- [Homepage GitHub](https://github.com/gethomepage/homepage)
- [AutoKuma GitHub](https://github.com/BigBoot/AutoKuma)
- [Docker Socket Proxy](https://github.com/Tecnativa/docker-socket-proxy)
- [Uptime Kuma Wiki - Docker Monitoring](https://github.com/louislam/uptime-kuma/wiki/How-to-Monitor-Docker-Containers)
- [Docker Swarm Service Labels](https://docs.docker.com/engine/swarm/services/#create-services-using-templates)

## Related ADRs

- [ADR-0033: TrueNAS Swarm Migration](ADR-0033-truenas-swarm-migration.md)
- [ADR-0032: 1Password Connect for Swarm](ADR-0032-onepassword-connect-swarm.md)
- [ADR-0022: Komodo-Managed Stacks](ADR-0022-truenas-komodo-stacks.md)

## Appendices

### A. Complete Label Reference

See `stacks/platform/observability/AUTOKUMA_LABELS.md` for comprehensive examples.

### B. Common Label Patterns

**HTTP Service with Health Check**:
```yaml
caddy: app.in.hypyr.space
caddy.reverse_proxy: "{{upstreams 8080}}"
caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
kuma.app.http.name: "Application Name"
kuma.app.http.url: "https://app.in.hypyr.space/health"
kuma.app.http.interval: "60"
```

**Internal Database Service**:
```yaml
kuma.db.port.name: "PostgreSQL Database"
kuma.db.port.hostname: "postgres"
kuma.db.port.port: "5432"
kuma.db.port.interval: "60"
```

**Container Health Monitoring**:
```yaml
kuma.worker.docker.name: "Background Worker"
kuma.worker.docker.docker_container: "worker"
kuma.worker.docker.docker_host: "1"
kuma.worker.docker.interval: "60"
```
