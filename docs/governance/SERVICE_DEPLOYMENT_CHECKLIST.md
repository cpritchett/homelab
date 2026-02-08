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

### 3. Homepage Dashboard Labels (required for all services)

Required labels:
- [ ] `homepage.group` - Category/group name (e.g., "Infrastructure", "Platform", "Applications")
- [ ] `homepage.name` - Display name for the service
- [ ] `homepage.icon` - Icon file or MDI icon name
- [ ] `homepage.href` - Service URL
- [ ] `homepage.description` - Short description

Optional (but recommended):
- [ ] `homepage.widget.type` - Widget type if service has API
- [ ] `homepage.widget.url` - Widget API endpoint
- [ ] `homepage.widget.key` - API key for widget (use variable)

Example:
```yaml
deploy:
  labels:
    homepage.group: "Platform"
    homepage.name: "My Application"
    homepage.icon: "myapp.png"
    homepage.href: "https://myapp.in.hypyr.space"
    homepage.description: "Application description"
```

### 4. Caddy Ingress Labels (if publicly accessible)

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

### 5. AutoKuma Monitoring Labels (required for all services)

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

### 6. Network Configuration

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

### 7. Volume Mounts

- [ ] Data stored on persistent datasets (`/mnt/apps01` or `/mnt/data01`)
- [ ] Directory structure documented in README
- [ ] Ownership/permissions specified in prerequisites

### 8. Komodo Deployment Compatibility (ADR-0022)

**CRITICAL**: All platform and application tier stacks MUST be deployable via Komodo UI without external scripts.

- [ ] Stack can be deployed via Komodo UI (Stacks → Deploy from Repository)
- [ ] No custom deployment scripts required (bootstrap tier exceptions only)
- [ ] All prerequisites handled by validation scripts (not deployment scripts)
- [ ] Compose file is self-contained and declarative

**Allowed Scripts**:
- ✅ **Pre-deployment validation** - Checks prerequisites, creates directories, verifies connectivity
  - MUST be idempotent (safe to run multiple times)
  - MUST NOT pull from git (Komodo handles git sync)
  - MUST NOT deploy stacks (Komodo handles deployment)
  - Should be configured as Komodo pre-deploy hooks
- ✅ **Setup/prerequisite scripts** - One-time environment preparation (permissions, directories)
- ❌ **Deployment scripts** - Scripts that run `docker stack deploy` are NOT allowed (except infrastructure bootstrap)

**Exception**: Infrastructure tier (`stacks/infrastructure/`) can use deployment scripts for bootstrapping because Komodo depends on this tier.

**Decision Rule**:
- Actual deployment (`docker stack deploy`) MUST be done via Komodo UI
- Git operations (`git pull`, `git clone`) MUST be done via Komodo UI
- Scripts can validate and prepare, but CANNOT deploy or sync git
- If a script runs `docker stack deploy` or `git pull`, it violates ADR-0022

**Pre-Deployment Hook Requirements**:
- [ ] Script is idempotent (checks before creating/modifying)
- [ ] Script does NOT run git commands
- [ ] Script does NOT run docker stack deploy
- [ ] Script validates prerequisites and fails fast if not met
- [ ] Script creates directories only if they don't exist
- [ ] Script sets permissions only if incorrect
- [ ] Script is fast enough to run before every deployment (< 10 seconds)

### 9. Label-Driven Pattern Compliance (ADR-0034)

**CRITICAL**: If adding a new tool to the stack, check if it supports Docker labels:

- [ ] Tool documentation reviewed for label/annotation support
- [ ] If labels are supported, using labels instead of config files
- [ ] If labels NOT supported, documented in ADR why manual config is acceptable

**Examples of label-supporting tools**:
- Ingress: Caddy ✓, Traefik
- Monitoring: AutoKuma ✓, Diun, Shepherd
- Dashboard: Homepage ✓
- Scheduling: Ofelia

**Decision Rule**: If a tool supports labels, labels MUST be used. No exceptions.

### 10. Documentation

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
  "homepage.group": "Applications",
  "homepage.name": "Service Name",
  "homepage.icon": "service.png",
  "homepage.href": "https://service.in.hypyr.space",
  "homepage.description": "Service description",
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

### 3. Verify Homepage Discovery

```bash
# Check Homepage logs for service discovery
sudo docker service logs platform_observability_homepage | grep <service-name>

# Check Homepage UI
# 1. Navigate to https://home.in.hypyr.space
# 2. Look for service in correct group
# 3. Verify service details and link work
# 4. Verify widget displays (if configured)
```

### 4. Verify AutoKuma Monitor Creation

```bash
# Check AutoKuma logs
sudo docker service logs platform_observability_autokuma | grep <monitor-id>

# Check Uptime Kuma UI
# 1. Navigate to https://status.in.hypyr.space
# 2. Look for monitor with "autokuma" tag
# 3. Verify monitor is UP
```

### 5. Verify Service Health

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
- [ ] **Homepage labels present and correct**
- [ ] Caddy labels correct (if publicly accessible)
- [ ] AutoKuma labels present and correct
- [ ] Service attached to `proxy_network` if needed
- [ ] Networks properly declared
- [ ] Resource limits configured
- [ ] README documentation complete
- [ ] Prerequisites documented
- [ ] Dashboard group and monitor specifications clear

When reviewing PRs that add new infrastructure tools:

- [ ] Tool checked for label/annotation support
- [ ] If labels supported, label-based config used
- [ ] If labels NOT supported, justification in PR description
- [ ] Pattern documented in ADR if new pattern established

## References

- [ADR-0034: Label-Driven Infrastructure](../adr/ADR-0034-label-driven-infrastructure.md) - Governance requirement
- [AutoKuma Label Examples](../../stacks/platform/observability/AUTOKUMA_LABELS.md) - Comprehensive examples
- [Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy) - Caddy label documentation
- [AutoKuma GitHub](https://github.com/BigBoot/AutoKuma) - AutoKuma label documentation
