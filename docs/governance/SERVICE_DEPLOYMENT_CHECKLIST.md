# Service Deployment Checklist

This checklist enforces governance requirements from [ADR-0034: Label-Driven Infrastructure](../adr/ADR-0034-label-driven-infrastructure.md).

## Pre-Deployment Requirements

### 1. Compose File Structure

- [ ] Service uses Swarm-compatible compose format
- [ ] No `depends_on`, `restart`, `container_name`, or `build` directives
- [ ] `deploy` section present with `restart_policy` and `resources`
- [ ] Health checks defined (if applicable)
- [ ] Resource limits configured (CPU and memory)

### 2. Label Placement (CRITICAL)

- [ ] Caddy labels under `deploy.labels` (NOT `labels`)
- [ ] AutoKuma labels under `deploy.labels` (NOT `labels`)
- [ ] Verified label placement with:
  ```bash
  grep -A 10 "deploy:" compose.yaml | grep -A 5 "labels:"
  ```

### 3. Caddy Ingress Labels (if publicly accessible)

Required labels:
- [ ] `caddy: <domain>` - Domain name (e.g., `app.in.hypyr.space`)
- [ ] `caddy.reverse_proxy: "{{upstreams <port>}}"` - Upstream target
- [ ] `caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"` - TLS DNS challenge

Example:
```yaml
deploy:
  labels:
    caddy: myapp.in.hypyr.space
    caddy.reverse_proxy: "{{upstreams 8080}}"
    caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
```

### 4. AutoKuma Monitoring Labels (required for all services)

Minimum labels:
- [ ] `kuma.<id>.<type>.name` - Monitor display name
- [ ] `kuma.<id>.<type>.url` or equivalent target - What to monitor
- [ ] `kuma.<id>.<type>.interval` - Check interval in seconds

Example - External HTTP:
```yaml
deploy:
  labels:
    kuma.myapp.http.name: "My Application"
    kuma.myapp.http.url: "https://myapp.in.hypyr.space"
    kuma.myapp.http.interval: "60"
    kuma.myapp.http.maxretries: "3"
```

Example - Internal Service:
```yaml
deploy:
  labels:
    kuma.mydb.port.name: "PostgreSQL Database"
    kuma.mydb.port.hostname: "postgres"
    kuma.mydb.port.port: "5432"
    kuma.mydb.port.interval: "60"
```

### 5. Network Configuration

- [ ] Service attached to `proxy_network` if using Caddy ingress
- [ ] `proxy_network` declared as external network
- [ ] Internal networks use `driver: overlay` for Swarm

Example:
```yaml
networks:
  - proxy_network
  - myapp_internal

networks:
  proxy_network:
    external: true
  myapp_internal:
    driver: overlay
```

### 6. Volume Mounts

- [ ] Data stored on persistent datasets (`/mnt/apps01` or `/mnt/data01`)
- [ ] Directory structure documented in README
- [ ] Ownership/permissions specified in prerequisites

### 7. Documentation

- [ ] Stack README.md exists
- [ ] README documents all external URLs
- [ ] README lists all auto-created monitors
- [ ] README includes prerequisite commands
- [ ] README shows deployment configuration for Komodo UI

README template:
```markdown
# Service Name

Description of what this service does.

## Services

- **Service Name** - https://service.in.hypyr.space
  - Purpose
  - Data location

## Prerequisites

\```bash
sudo mkdir -p /mnt/apps01/appdata/service
sudo chown -R 1000:1000 /mnt/apps01/appdata/service
\```

## Deployment

**Stack Name:** `platform_service`
**Run Directory:** `stacks/platform/category/service/`

## Monitors

AutoKuma will create:
- Service Name (HTTPS) - https://service.in.hypyr.space
- Service Database (TCP) - postgres:5432

## External Access

- Main UI: https://service.in.hypyr.space
```

## Deployment Steps

### 1. Create Prerequisites

```bash
# SSH to TrueNAS
ssh truenas_admin@barbary

# Create directories
sudo mkdir -p /mnt/apps01/appdata/<service>
sudo chown -R <uid>:<gid> /mnt/apps01/appdata/<service>

# Create secrets if needed (via 1Password templates)
```

### 2. Deploy via Komodo UI

1. Navigate to **Stacks** in Komodo
2. Create new Stack:
   - Name: `platform_<service>`
   - Server: `barbary-periphery`
3. Configure **Files**:
   - Run Directory: `stacks/platform/<category>/<service>/`
   - File Paths: Leave empty (uses compose.yaml)
4. **Save** and **Deploy**

### 3. Monitor Deployment

Watch deployment logs in Komodo UI until all services show `1/1`.

## Post-Deployment Validation

### 1. Verify Service Labels

```bash
# SSH to TrueNAS
ssh truenas_admin@barbary

# Check service labels
sudo docker service inspect platform_<service>_<service-name> \
  --format '{{json .Spec.Labels}}' | jq .

# Should show caddy and kuma labels
```

Expected output:
```json
{
  "caddy": "service.in.hypyr.space",
  "caddy.reverse_proxy": "{{upstreams 8080}}",
  "caddy.tls.dns": "cloudflare {env.CLOUDFLARE_API_TOKEN}",
  "kuma.service.http.name": "Service Name",
  "kuma.service.http.url": "https://service.in.hypyr.space",
  "kuma.service.http.interval": "60"
}
```

### 2. Verify Caddy Discovery

```bash
# Check Caddy logs for service discovery
sudo docker service logs caddy_caddy | grep <domain>

# Test external access
curl -I https://<domain>
# Should return HTTP 200 or valid response
```

### 3. Verify AutoKuma Monitor Creation

```bash
# Check AutoKuma logs
sudo docker service logs platform_observability_autokuma | grep <monitor-id>

# Check Uptime Kuma UI
# 1. Navigate to https://status.in.hypyr.space
# 2. Look for monitor with "autokuma" tag
# 3. Verify monitor is UP
```

### 4. Verify Service Health

```bash
# Check service status
sudo docker service ls | grep <service>

# Check service tasks
sudo docker service ps platform_<service>_<service-name>

# Check logs
sudo docker service logs platform_<service>_<service-name> --tail 50
```

## Troubleshooting

### Labels Not Applied

**Symptom:** Caddy doesn't discover service, AutoKuma doesn't create monitor

**Check:**
```bash
sudo docker service inspect <service> --format '{{json .Spec.Labels}}'
```

**Common Cause:** Labels under `labels:` instead of `deploy.labels:`

**Fix:**
1. Move labels to `deploy.labels:` in compose file
2. Commit changes to Git
3. Redeploy via Komodo UI

### Service Not Accessible (502/503)

**Check:**
1. Service is running: `docker service ps <service>`
2. Service is on proxy_network: `docker service inspect <service> --format '{{json .Spec.TaskTemplate.Networks}}'`
3. Caddy can reach service: `docker exec <caddy-container> wget -qO- http://<service>:<port>`

### Monitor Not Created

**Check AutoKuma logs:**
```bash
sudo docker service logs platform_observability_autokuma --tail 50
```

**Common issues:**
- Uptime Kuma not initialized (need to create admin account first)
- AutoKuma can't reach Uptime Kuma API
- Label syntax error
- Monitor ID already exists with different configuration

**Fix:**
1. Complete Uptime Kuma initial setup
2. Wait 60 seconds for next AutoKuma sync
3. Check logs for specific error messages

## Code Review Checklist

When reviewing PRs that add new services:

- [ ] Compose file is Swarm-compatible
- [ ] Labels present under `deploy.labels`
- [ ] Caddy labels correct (if publicly accessible)
- [ ] AutoKuma labels present and correct
- [ ] Service attached to `proxy_network` if needed
- [ ] Networks properly declared
- [ ] Resource limits configured
- [ ] README documentation complete
- [ ] Prerequisites documented
- [ ] Monitor specifications clear

## References

- [ADR-0034: Label-Driven Infrastructure](../adr/ADR-0034-label-driven-infrastructure.md) - Governance requirement
- [AutoKuma Label Examples](../../stacks/platform/observability/AUTOKUMA_LABELS.md) - Comprehensive examples
- [Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy) - Caddy label documentation
- [AutoKuma GitHub](https://github.com/BigBoot/AutoKuma) - AutoKuma label documentation
