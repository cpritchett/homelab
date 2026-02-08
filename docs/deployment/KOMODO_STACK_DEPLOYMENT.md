# Deploying Stacks via Komodo UI

This guide explains how to deploy platform and application stacks using the Komodo UI instead of direct `docker stack deploy` commands.

**Version**: Written for Komodo v2-dev (images: `ghcr.io/moghtech/komodo-core:2-dev`, `ghcr.io/moghtech/komodo-periphery:2-dev`)

## Komodo v2 Stack Configuration UI

The Stack configuration UI is organized into sections:

**GENERAL Section:**
- **Source**: Configure Git repository settings (Files, Config Files, Auto Update, Links, Webhooks)
  - Clone Path: Where to clone repo on host
  - Reclone: Whether to delete and reclone (vs git pull)

**ADVANCED Section:**
- Project Name, Pre/Post Deploy hooks, Wrapper, Extra Args
- Ignore Services, Pull Images, Destroy options

**Files Section:**
- **Run Directory**: Working directory for `docker compose` command (relative to repo root)
- **File Paths**: Compose files to include with `-f` flag (defaults to compose.yaml if empty)

**Config Files Section:**
- Additional files to manage and edit in Komodo UI

**Auto Update Section:**
- Poll For Updates: Check registries for new image versions
- Auto Update: Automatically redeploy on new images

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

### Step 2: Create a Stack

1. Navigate to **Stacks** in Komodo UI
2. Click **Create Stack** (or similar button)
3. Enter a **Stack Name** (e.g., `platform_homepage`)
4. Select **Server**: `barbary-periphery` (your Swarm manager)

### Step 3: Configure Stack Source

In the **GENERAL** section:

**Source Settings:**
- **Source Type**: Select "Files" (for Git repository)
- **Clone Path**: Can specify custom path on host, or leave default
  - Path is relative to `$root_directory/stacks/platform_homepage`
  - If absolute (starts with `/`), uses that exact path
- **Reclone**: DISABLED (uses `git pull` for updates instead of recloning)

### Step 4: Configure Files

In the **Files** section:

**Run Directory:**
- Set the working directory for `docker compose` command
- Path is relative to the repository root
- Example: `stacks/platform/observability/homepage/`

**File Paths:**
- Add compose files to include using `docker compose -f`
- If left empty, uses `compose.yaml` by default
- Paths are relative to **Run Directory**
- Examples:
  - Leave empty → uses `compose.yaml`
  - Add `homepage-compose.yaml` → uses that specific file
  - Add multiple files for multi-file compose setups

**Config Files** (optional):
- Add other config files to associate with the Stack
- These can be edited directly in Komodo UI
- Paths are relative to **Run Directory**
- Useful for managing service configuration files

### Step 5: Configure Auto Update (Optional)

In the **Auto Update** section:

**Poll For Updates:**
- Enable to check for Docker image updates on an interval
- Useful for tracking when new versions are available

**Auto Update:**
- Enable to trigger automatic redeployment when newer images are found
- Recommended for dev environments, use caution in production

**Full Stack Auto Update:**
- Additional auto-update options

### Step 6: Advanced Options (Optional)

In the **ADVANCED** section:

- **Project Name**: Override the default project name
- **Pre Deploy**: Scripts/commands to run before deployment
- **Post Deploy**: Scripts/commands to run after deployment
- **Wrapper**: Wrapper command for the compose execution
- **Extra Args**: Additional arguments to pass to `docker compose`
- **Ignore Services**: Services to exclude from deployment
- **Pull Images**: Force pull images before deploying
- **Destroy**: Full stack destruction options

### Step 7: Save and Deploy

1. Click **Save** to save the stack configuration
2. Click **Deploy** (or **Redeploy** if already deployed)
3. Monitor deployment progress in real-time

### Step 8: Verify Deployment

**In Komodo UI:**
- Check service status - all should show as running (e.g., 1/1)
- Review service logs if issues are detected
- Verify configuration was applied correctly

**External Access:**
- Test the configured domain (e.g., https://home.in.hypyr.space)
- Verify TLS certificate is valid
- Confirm the application loads correctly

## Example: Deploying Homepage Stack

**Stack Configuration:**
- **Name**: `platform_homepage`
- **Server**: `barbary-periphery`

**Files Section:**
- **Run Directory**: `stacks/platform/observability/homepage/`
- **File Paths**: `homepage-compose.yaml` (or leave empty for compose.yaml)

**Config Files** (optional):
- `config/services.yaml`
- `config/settings.yaml`
- `config/bookmarks.yaml`

This allows you to edit Homepage configuration directly in Komodo UI without SSH access.

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

**Manual Update:**
1. Push changes to GitHub repository
2. In Komodo UI, navigate to the stack
3. Click **Redeploy** button
4. Komodo will pull latest changes from Git and redeploy

**Automatic Updates (Image):**
1. Enable **Poll For Updates** in Auto Update section
2. Enable **Auto Update** to trigger automatic redeployment
3. Komodo will monitor Docker Hub/registries for new image versions
4. Automatically redeploy when newer images are available

**Automatic Updates (Git):**
- Configure webhooks to trigger redeployment on Git push
- See **Webhooks** section in GENERAL settings

### Rolling Back

Komodo tracks deployment history:
1. Navigate to your stack in Komodo UI
2. Look for deployment history or versions
3. Select a previous deployment to restore
4. Confirm rollback action

Note: Specific rollback UI may vary in v2-dev. You can also manually:
- Revert Git commits and redeploy
- Specify older image tags in compose file
- Use `docker service rollback` via CLI if needed

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
