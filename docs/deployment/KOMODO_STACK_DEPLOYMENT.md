# Deploying Stacks via Komodo UI

This guide explains how to deploy platform and application stacks using the Komodo UI instead of direct `docker stack deploy` commands.

**Note**: This guide is written for Komodo v2-dev. The exact UI navigation may differ from older versions. This guide focuses on concepts and configuration requirements rather than specific menu locations.

## Why Use Komodo UI?

- **Centralized Management**: Single interface for all stacks
- **Git Integration**: Stacks sync from repository automatically
- **Template Support**: Environment variable injection from 1Password
- **Health Monitoring**: Visual status of all services
- **Rollback Support**: Easy rollback to previous versions
- **RBAC**: Role-based access control for team deployments

## Stack Organization for Komodo

### Directory Structure

```
stacks/
├── infrastructure/          # Already deployed via bootstrap script
│   ├── op-connect-compose.yaml
│   ├── komodo-compose.yaml
│   └── caddy-compose.yaml
│
├── platform/               # Deploy via Komodo UI
│   ├── observability/
│   │   ├── homepage/
│   │   │   └── homepage-compose.yaml
│   │   └── uptime-kuma/
│   │       └── compose.yaml
│   ├── auth/
│   │   └── authentik/
│   │       └── compose.yaml
│   └── monitoring/         # To be created
│       └── grafana-stack/
│           └── compose.yaml
│
└── applications/           # Future application stacks
```

### Stack Naming Convention

- **File name**: `{service}-compose.yaml` or `compose.yaml`
- **Stack name in Komodo**: `{tier}_{service}` (e.g., `platform_homepage`, `platform_authentik`)
- **Network naming**: Use external networks (`proxy_network`, `op-connect_op-connect`)

## Preparing Stacks for Komodo Deployment

### 1. Remove Unsupported Compose Features

Komodo deploys to Docker Swarm, so remove these from compose files:

```yaml
# REMOVE these (not supported in Swarm):
depends_on:        # Swarm doesn't enforce startup order
container_name:    # Swarm generates names automatically
restart:           # Use deploy.restart_policy instead
build:             # Must use pre-built images
```

### 2. Convert to Swarm-Compatible Format

**Before (Docker Compose):**
```yaml
services:
  app:
    image: myapp:latest
    restart: unless-stopped
    depends_on:
      - database
    container_name: myapp
```

**After (Swarm-Compatible):**
```yaml
services:
  app:
    image: myapp:latest
    deploy:
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          cpus: '1'
          memory: 512M
    # No depends_on, no container_name, no restart
```

### 3. Handle Secrets Properly

**Option A: Swarm Secrets (for infrastructure tier)**
```yaml
services:
  app:
    secrets:
      - my_secret
secrets:
  my_secret:
    external: true
```

**Option B: 1Password Connect (for platform/app tier)**
```yaml
services:
  secrets-init:
    image: 1password/op:2
    environment:
      OP_CONNECT_HOST: http://op-connect-api:8080
      OP_CONNECT_TOKEN_FILE: /run/secrets/op_connect_token
    secrets:
      - op_connect_token
    networks:
      - op-connect
    command: >
      sh -c "
      export OP_CONNECT_TOKEN=$$(cat /run/secrets/op_connect_token) &&
      op inject -i /templates/app.template -o /secrets/app.env -f
      "

  app:
    image: myapp:latest
    volumes:
      - /mnt/apps01/appdata/myapp/secrets:/secrets:ro
    entrypoint: ["/bin/sh", "-c"]
    command: >
      "set -a && [ -f /secrets/app.env ] && . /secrets/app.env && set +a &&
       exec myapp-entrypoint"
```

### 4. Ensure Network Configuration

All stacks should use the `proxy_network` for Caddy ingress:

```yaml
services:
  app:
    labels:
      caddy: myapp.in.hypyr.space
      caddy.reverse_proxy: "{{upstreams 8080}}"
      caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
    networks:
      - proxy_network
      - internal  # Optional internal network

networks:
  proxy_network:
    external: true
  internal:
    driver: overlay
```

## Deploying Stacks via Komodo UI

### Step 1: Access Komodo

Navigate to https://komodo.in.hypyr.space and log in with admin credentials.

### Step 2: Add Repository (One-Time Setup)

You need to configure Komodo to access your Git repository. The exact location in the UI may vary, but you're looking to create a **Git Provider** or **Resource Sync** with these settings:

**Configuration:**
- **Name**: `homelab-repo`
- **Repository URL**: `https://github.com/cpritchett/homelab`
- **Branch**: `main`
- **Auto-sync**: Enabled (check for updates every 5 minutes or on webhook)

This allows Komodo to pull compose files directly from your repository.

### Step 3: Create a Stack

Create a new **Stack** resource with these key settings:

**Essential Configuration:**
- **Stack Name**: Descriptive name (e.g., `platform_homepage`)
- **Target Server**: `barbary-periphery` (your Swarm manager)
- **Compose File Source**: Choose Git repository option
  - **Repository/Provider**: `homelab-repo` (from Step 2)
  - **File Path**: Relative path to compose file (e.g., `stacks/platform/observability/homepage/homepage-compose.yaml`)
  - **Branch**: `main`
- **Auto-deploy**: Enable if you want automatic deployment on git push

**Optional Configuration:**
- **Environment Variables**: Add any stack-specific variables if needed
- **Additional Compose Files**: For advanced multi-file setups

### Step 4: Deploy the Stack

Once the stack is created and configured:
1. Locate your stack in the Komodo UI
2. Find the deploy/redeploy action (button, menu item, or similar)
3. Execute the deployment
4. Monitor the deployment progress - Komodo should show real-time status

### Step 5: Verify Deployment

**In Komodo UI:**
- Check that all services within the stack show as running
- Review service logs if any issues are detected
- Verify configuration was applied correctly

**External Access:**
- Test the configured domain (e.g., https://home.in.hypyr.space)
- Verify TLS certificate is valid
- Confirm the application loads correctly

## Stack Deployment Order (Recommended)

Deploy in this order to satisfy dependencies:

### Phase 2A: Core Platform Services

1. **homepage** - Dashboard for monitoring deployments
   - Path: `stacks/platform/observability/homepage/homepage-compose.yaml`
   - Domain: `home.in.hypyr.space`

2. **authentik** - SSO/Authentication
   - Path: `stacks/platform/auth/authentik/compose.yaml`
   - Domain: `auth.in.hypyr.space`
   - **Prerequisites**: Create secrets directory and run secrets-init manually first

3. **uptime-kuma** - Basic uptime monitoring
   - Path: `stacks/platform/observability/uptime-kuma/compose.yaml`
   - Domain: `status.in.hypyr.space`

### Phase 2B: Monitoring Stack

4. **monitoring** - Prometheus + Grafana + Loki
   - Path: `stacks/platform/monitoring/grafana-stack/compose.yaml` (to be created)
   - Domains: `prometheus.in.hypyr.space`, `grafana.in.hypyr.space`, `loki.in.hypyr.space`

## Stack Updates and Rollback

### Updating a Stack

1. Push changes to GitHub repository
2. In Komodo UI, navigate to the stack
3. Click **Redeploy** (will pull latest from Git)
4. Or enable **Auto-Update** to deploy on every Git push

### Rolling Back

1. Navigate to stack in Komodo UI
2. Click **Actions → Rollback**
3. Select previous version
4. Confirm rollback

## Troubleshooting Stack Deployments

### Service Won't Start

1. **Check Logs**: View service logs in Komodo UI
2. **Check Health**: Verify service health checks in stack definition
3. **Check Networks**: Ensure all required networks exist
4. **Check Secrets**: Verify Swarm secrets are created

```bash
# On TrueNAS, check secrets
docker secret ls

# Check networks
docker network ls | grep -E 'proxy|op-connect'

# Check service status
docker service ps platform_homepage_homepage
```

### Secrets-Init Container Fails

1. **Verify 1Password Connect is running**:
   ```bash
   docker service ls | grep op-connect
   ```

2. **Check op_connect_token secret exists**:
   ```bash
   docker secret inspect op_connect_token
   ```

3. **Verify secrets directory permissions**:
   ```bash
   ls -la /mnt/apps01/appdata/{service}/secrets
   ```

### Stack Deploy Fails in Komodo

1. **Validate compose file locally**:
   ```bash
   docker stack deploy --compose-file compose.yaml test-stack
   docker stack rm test-stack
   ```

2. **Check Komodo Periphery logs**:
   - View in Komodo UI under Infrastructure logs
   - Or via CLI: `docker service logs komodo_periphery`

3. **Verify Git path is correct**:
   - Ensure path in Komodo matches actual file location in repo

## Best Practices

### 1. Use Git as Source of Truth
- Always deploy from Git, not local files
- Commit and push changes before deploying
- Use branches for testing major changes

### 2. Resource Limits
- Always set CPU and memory limits
- Prevents runaway containers from affecting other services

```yaml
deploy:
  resources:
    limits:
      cpus: '1'
      memory: 512M
    reservations:
      cpus: '0.5'
      memory: 256M
```

### 3. Health Checks
- Define health checks for critical services
- Allows automatic restart of unhealthy containers

```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--spider", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 4. Labels for Organization
- Use labels to group related services
- Enables filtering in Komodo UI

```yaml
labels:
  app.tier: platform
  app.category: observability
  app.version: v1.2.3
```

### 5. Persistent Data
- Store data on `/mnt/apps01/appdata/` or `/mnt/data01/appdata/`
- Use consistent directory structure per service
- Set proper ownership (UID:GID matching container user)

## Example: Complete Stack for Komodo

```yaml
# stacks/platform/example/compose.yaml
services:
  app:
    image: myapp:v1.0.0
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
      resources:
        limits:
          cpus: '1'
          memory: 512M
    environment:
      APP_ENV: production
    labels:
      # Caddy ingress
      caddy: myapp.in.hypyr.space
      caddy.reverse_proxy: "{{upstreams 8080}}"
      caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
      # Organization
      app.tier: platform
      app.category: example
    networks:
      - proxy_network
      - internal
    volumes:
      - /mnt/apps01/appdata/myapp/data:/data
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  proxy_network:
    external: true
  internal:
    driver: overlay
```

## Monitoring Stack Health

Once deployed, monitor stack health via:

1. **Komodo UI** - Visual service status and logs
2. **Homepage Dashboard** - https://home.in.hypyr.space
3. **Uptime Kuma** - https://status.in.hypyr.space (once deployed)
4. **Grafana** - https://grafana.in.hypyr.space (once monitoring stack deployed)

## Next Steps

After deploying platform stacks via Komodo:
1. Configure Authentik providers for each service
2. Set up forward-auth with Caddy
3. Configure monitoring dashboards in Grafana
4. Deploy application stacks (media, home automation, etc.)
