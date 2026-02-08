# Authentik SSO Platform - Deployment Guide

## Overview

This guide covers deploying the Authentik SSO platform stack on TrueNAS Scale Docker Swarm.

**Stack Components:**
- Authentik Server (OIDC/SAML provider)
- Authentik Worker (background tasks)
- PostgreSQL 18 (database)
- Redis 8 (cache/message queue)
- Secrets-init (1Password Connect integration)

## Label-Driven Integration

Per [ADR-0034](../../../../docs/adr/ADR-0034-label-driven-infrastructure.md), this stack includes all three required label sets:

### Homepage Dashboard
- Group: "Platform"
- Widget: Authentik API integration
- Auto-discovered from deploy.labels

### Caddy Reverse Proxy
- Domain: auth.in.hypyr.space
- TLS: Cloudflare DNS challenge
- Automatic certificate management

### AutoKuma Monitoring
- HTTP health checks to https://auth.in.hypyr.space
- Accepts 200-299, 301, 302 status codes
- Auto-created monitors in Uptime Kuma

## Prerequisites

### 1. Infrastructure Tier Running

Verify infrastructure services are deployed:

```bash
docker service ls | grep -E 'op-connect|komodo|caddy'
```

Expected output:
```
op-connect_op-connect-api
op-connect_op-connect-sync
komodo_core
komodo_mongo
komodo_periphery
caddy_caddy
caddy_docker-socket-proxy
```

### 2. Docker Networks

Verify required networks exist:

```bash
docker network ls | grep -E 'proxy_network|op-connect'
```

Expected output:
```
proxy_network            overlay
op-connect_op-connect    overlay
```

### 3. Docker Secrets

Verify required secrets exist:

```bash
docker secret ls | grep -E 'op_connect_token|CLOUDFLARE_API_TOKEN'
```

Both secrets must exist from infrastructure deployment.

### 4. 1Password Vault Setup

Ensure the following secrets exist in your 1Password `homelab` vault:

**Item: "authentik-stack"**
- Field: `secret_key` - Django secret key (generate with `openssl rand -base64 50`)
- Field: `bootstrap_email` - Admin email address
- Field: `bootstrap_password` - Admin password (min 8 characters)
- Field: `postgres_password` - PostgreSQL password

Verify secrets are accessible:

```bash
# On your workstation with op CLI authenticated
op item get "authentik-stack" --vault homelab --fields label
```

### 5. ZFS Datasets

Verify datasets exist and have space:

```bash
zfs list | grep -E 'apps01|data01'
df -h /mnt/apps01 /mnt/data01
```

## Deployment Method

Per [ADR-0022](../../../../docs/adr/ADR-0022-truenas-komodo-stacks.md), deployment is done via Komodo UI. Pre-deployment validation runs automatically as a Komodo hook.

### Deploy via Komodo UI

1. Access https://komodo.in.hypyr.space
2. Navigate to **Stacks** → **Add Stack**
3. Configure stack:
   - **Repository**: homelab
   - **Path**: stacks/platform/auth/authentik
   - **File**: compose.yaml (default)
   - **Server**: barbary-periphery
   - **Pre-Deploy Hook** (optional): `scripts/validate-authentik-setup.sh`
4. Click **Deploy**
5. Monitor deployment in Komodo UI

**What happens automatically:**
- Komodo syncs the repository (pulls latest code)
- Pre-deployment hook validates prerequisites (if configured)
- Directories are created with correct permissions
- Stack is deployed via `docker stack deploy`
- Services start and are monitored

**Duration:** ~3-5 minutes total

### Manual Prerequisite Validation (Optional)

The pre-deployment hook runs automatically in Komodo. If you want to test it manually first:

```bash
# SSH to TrueNAS
ssh root@barbary

# Komodo already synced the repo, so just run validation
sudo /mnt/apps01/repos/homelab/scripts/validate-authentik-setup.sh
```

This is idempotent and safe to run multiple times. Komodo can be configured to run this automatically before every deployment.

**Note:** Do NOT run `docker stack deploy` directly. Use Komodo UI per ADR-0022.

## Post-Deployment

### 1. Monitor Service Startup

Watch services come online:

```bash
# Watch service status
watch -n 2 'docker service ls --filter "label=com.docker.stack.namespace=authentik"'

# Check service logs
docker service logs -f authentik_authentik-server
docker service logs -f authentik_postgresql
docker service logs -f authentik_secrets-init
```

**Expected timeline:**
- secrets-init: completes in ~5 seconds
- postgresql: ready in ~30 seconds
- redis: ready in ~10 seconds
- authentik-server: ready in ~60 seconds
- authentik-worker: ready in ~30 seconds

### 2. Verify Secret Injection

Check that 1Password secrets were injected:

```bash
ls -la /mnt/apps01/appdata/authentik/secrets/
```

Expected files:
- `authentik.env` - Authentik configuration
- `postgres.env` - PostgreSQL credentials

### 3. Access Authentik UI

1. Wait 2-3 minutes for complete initialization
2. Navigate to: https://auth.in.hypyr.space
3. Should see Authentik login page with valid TLS certificate

### 4. Initial Setup

**First-time setup:**

1. Click "Sign up" (if registration is enabled) or use bootstrap credentials
2. Login with bootstrap email/password from 1Password
3. Complete the setup wizard
4. Configure:
   - Flows (authentication, authorization, enrollment)
   - Applications (services to protect)
   - Providers (OIDC, SAML, OAuth2)
   - Users and groups

**Create API token for Homepage widget:**

1. Navigate to Admin Interface → Tokens and App passwords
2. Create new token:
   - Name: "Homepage Dashboard"
   - Scope: Read-only
   - Expiration: None (or long-lived)
3. Copy the token value
4. Add to Homepage environment variables:
   ```bash
   HOMEPAGE_VAR_AUTHENTIK_API_KEY=<token-value>
   ```

### 5. Verify Auto-Discovery

**Homepage Dashboard:**
- Navigate to https://home.in.hypyr.space
- Check "Platform" group
- Should see "Authentik" with widget showing user count
- Widget should display Authentik version and stats

**Uptime Kuma:**
- Navigate to https://status.in.hypyr.space
- Look for "Authentik SSO" monitor
- Should be auto-created by AutoKuma
- Status should be "Up"

**Caddy Logs:**
```bash
docker service logs caddy_caddy | grep "auth.in.hypyr.space"
```
- Should show TLS certificate obtained
- Should show reverse proxy configured

## Health Checks

### Service Health

```bash
# Check all services running
docker service ls --filter "label=com.docker.stack.namespace=authentik"

# Expected replicas: All 1/1
authentik_authentik-server   1/1
authentik_authentik-worker   1/1
authentik_postgresql         1/1
authentik_redis              1/1
```

### Database Health

```bash
# Test PostgreSQL connection
docker exec $(docker ps -q -f name=authentik_postgresql) \
  pg_isready -U authentik

# Should return: accepting connections
```

### Redis Health

```bash
# Test Redis connection
docker exec $(docker ps -q -f name=authentik_redis) \
  redis-cli ping

# Should return: PONG
```

### Authentik API Health

```bash
# Test from internal network
docker run --rm --network authentik_authentik \
  curlimages/curl:latest \
  curl -sf http://authentik-server:9000/-/health/ready/

# Should return: OK
```

### External Access

```bash
# Test TLS and external access
curl -I https://auth.in.hypyr.space

# Should return: HTTP/2 200 (or 302 redirect to login)
```

## Troubleshooting

### Secrets Not Injecting

**Symptom:** authentik-server fails to start, missing environment variables

**Check:**
```bash
docker service logs authentik_secrets-init

# Should see: "Secrets injected successfully"
```

**Fix:**
1. Verify 1Password Connect is running: `docker service ps op-connect_op-connect-api`
2. Verify secrets exist in vault: `op item get "authentik-stack" --vault homelab`
3. Check network connectivity between secrets-init and op-connect
4. Verify op_connect_token secret exists: `docker secret ls`

### PostgreSQL Permission Errors

**Symptom:** PostgreSQL fails to start with permission denied errors

**Check:**
```bash
ls -la /mnt/data01/appdata/authentik/postgres
```

**Fix:**
```bash
sudo chown -R 999:999 /mnt/data01/appdata/authentik/postgres
sudo chmod 700 /mnt/data01/appdata/authentik/postgres
```

### Authentik Server Crash Loop

**Symptom:** authentik-server repeatedly restarts

**Check:**
```bash
docker service logs authentik_authentik-server | tail -50
```

**Common causes:**
1. Database not ready - wait longer for PostgreSQL initialization
2. Missing secrets - check env files exist
3. Redis not accessible - verify redis service is running

### External Access 502/503

**Symptom:** Caddy returns 502 Bad Gateway or 503 Service Unavailable

**Check:**
```bash
# Verify service is on proxy_network
docker service inspect authentik_authentik-server \
  --format '{{json .Spec.TaskTemplate.Networks}}' | jq .

# Verify Caddy labels
docker service inspect authentik_authentik-server \
  --format '{{json .Spec.Labels}}' | jq .

# Check Caddy logs
docker service logs caddy_caddy | grep "auth.in.hypyr.space"
```

**Fix:**
1. Ensure authentik-server is connected to proxy_network
2. Verify Caddy labels are in deploy.labels section
3. Restart Caddy to pick up new labels: `docker service update --force caddy_caddy`

### Homepage Widget Not Showing

**Symptom:** Authentik appears in Homepage but widget is empty

**Cause:** Missing or invalid API token in Homepage environment

**Fix:**
1. Create API token in Authentik (see "Initial Setup" above)
2. Add to Homepage environment:
   ```bash
   # Via Komodo UI: platform_observability stack → Environment Variables
   HOMEPAGE_VAR_AUTHENTIK_API_KEY=<token>
   ```
3. Restart Homepage: `docker service update --force platform_observability_homepage`

### AutoKuma Not Creating Monitor

**Symptom:** No "Authentik SSO" monitor in Uptime Kuma

**Check:**
```bash
docker service logs platform_observability_autokuma | grep -i authentik
```

**Fix:**
1. Ensure Uptime Kuma is initialized (admin account created)
2. Verify AutoKuma is running and scanning labels (60s interval)
3. Check service labels: `docker service inspect authentik_authentik-server --format '{{json .Spec.Labels}}'`
4. Wait 1-2 minutes for next AutoKuma sync cycle

## Maintenance

### Update Authentik

```bash
# Edit compose.yaml to new version
vim /mnt/apps01/repos/homelab/stacks/platform/auth/authentik/compose.yaml

# Update image tag
# FROM: ghcr.io/goauthentik/server:2025.12.2
# TO:   ghcr.io/goauthentik/server:2025.12.3

# Redeploy
docker stack deploy -c /mnt/apps01/repos/homelab/stacks/platform/auth/authentik/compose.yaml authentik

# Monitor update
docker service logs -f authentik_authentik-server
```

### Backup Database

```bash
# Backup PostgreSQL
docker exec $(docker ps -q -f name=authentik_postgresql) \
  pg_dump -U authentik authentik > /mnt/apps01/backups/authentik-$(date +%Y%m%d).sql

# Or use ZFS snapshots
zfs snapshot data01/appdata/authentik@$(date +%Y%m%d)
```

### View Logs

```bash
# All Authentik services
docker service logs authentik_authentik-server
docker service logs authentik_authentik-worker
docker service logs authentik_postgresql
docker service logs authentik_redis

# Follow logs in real-time
docker service logs -f authentik_authentik-server

# Last 100 lines
docker service logs --tail 100 authentik_authentik-server
```

### Remove Stack

```bash
# Remove the stack
docker stack rm authentik

# Wait for services to shut down
watch docker service ls

# Remove volumes (careful - deletes data!)
docker volume rm authentik_authentik-data

# Remove directories (careful - deletes data!)
sudo rm -rf /mnt/data01/appdata/authentik
sudo rm -rf /mnt/apps01/appdata/authentik
```

## Next Steps

After Authentik is deployed and configured:

1. **Configure SSO for existing services:**
   - Homepage
   - Grafana
   - Uptime Kuma
   - Komodo
   - Other homelab services

2. **Set up OAuth/OIDC providers:**
   - Create applications in Authentik
   - Generate client IDs and secrets
   - Configure service OIDC settings

3. **Configure authentication flows:**
   - Multi-factor authentication (MFA)
   - Password policies
   - Account recovery
   - User enrollment

4. **User management:**
   - Create user accounts
   - Set up groups and permissions
   - Configure RBAC policies

## References

- [Authentik Documentation](https://docs.goauthentik.io/)
- [ADR-0034: Label-Driven Infrastructure](../../../../docs/adr/ADR-0034-label-driven-infrastructure.md)
- [Complete Label Examples](../../observability/COMPLETE_LABEL_EXAMPLES.md)
- [Homepage Authentik Widget](https://gethomepage.dev/latest/widgets/services/authentik/)
