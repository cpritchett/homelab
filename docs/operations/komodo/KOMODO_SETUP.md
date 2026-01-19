# Komodo Setup Guide for Barbary

This document provides a reproducible, minimal setup for Komodo on TrueNAS SCALE (Barbary) to deploy containerized stacks.

## Architecture Overview

### TrueNAS Apps (Recommended)
- **Komodo Core**: Web UI and orchestration engine
- **MongoDB**: Database backend for Komodo Core (can use bundled or external)

## Component Installation

### 1. Komodo Core (TrueNAS App)

Install Komodo Core from the TrueNAS app catalog:

1. Navigate to **Apps** → **Available Applications**
2. Search for "Komodo"
3. Install **Komodo Core** with these settings:
   - **Storage**: `/mnt/apps01/appdata/komodo`
   - **Port**: `9120` (web UI)
   - **Database**: Use bundled MongoDB or external instance

### 2. MongoDB (Optional External)

If using external MongoDB:

1. Install **MongoDB** from app catalog
2. Configure:
   - **Storage**: `/mnt/apps01/appdata/mongodb`
   - **Port**: `27017`
   - **Authentication**: Enable with strong credentials
3. Create database `komodo` for Komodo Core

## Stack Configuration

### Create Docker Network

Before deploying stacks, create the shared network:
```bash
docker network create proxy_network
```

### Configure Stacks in Komodo

For each stack in the repository, create a Komodo "Stack":

#### Proxy Stack
**Stack Name**: `proxy`
**Git Repository**: `https://github.com/cpritchett/homelab.git`
**Git Branch**: `main`
**Compose File Path**: `stacks/00-proxy/compose.yml`

**Environment Variables**:
```
CLOUDFLARE_API_TOKEN=your_actual_cloudflare_token
CADDY_EMAIL=admin@hypyr.space
TZ=America/Chicago
```

#### Harbor Stack
**Stack Name**: `harbor`
**Git Repository**: `https://github.com/cpritchett/homelab.git`
**Git Branch**: `main`
**Compose File Path**: `stacks/20-harbor/compose.yml`

**Environment Variables**:
```
TZ=America/Chicago
CLOUDFLARE_API_TOKEN=your_actual_cloudflare_token
HARBOR_ADMIN_PASSWORD=your_secure_password
POSTGRES_PASSWORD=your_postgres_password
HARBOR_SECRETKEY=your_harbor_secret_key
HARBOR_PRIVATE_KEY_PEM=your_private_key_pem
```

## Deployment Triggers

### 1. Manual Deploy

**Via Komodo Web UI:**
1. Navigate to **Stacks** → Select stack
2. Click **Deploy** or **Redeploy**
3. Monitor deployment logs in real-time

### 2. Webhook Deploy from GitHub

**Configure GitHub Webhook:**
1. Repository **Settings** → **Webhooks** → **Add webhook**
2. **Payload URL**: `http://barbary.in.hypyr.space:9120/api/stack/{stack-name}/webhook`
3. **Content type**: `application/json`
4. **Events**: Push events on `main` branch
5. **Secret**: Generate and store in Komodo webhook settings

**Komodo Webhook Configuration:**
1. **Stacks** → Select stack → **Webhooks**
2. Enable webhook with GitHub secret
3. Configure branch filter: `main`

### 3. Periodic Reconcile

**Configure Scheduled Deployment:**
1. **Stacks** → Select stack → **Schedule**
2. **Cron Expression**: `*/15 * * * *` (every 15 minutes)
3. **Enabled**: `true`
4. **Timezone**: `America/Los_Angeles`

**Alternative Cron Schedule Examples:**
```bash
# Every 15 minutes
*/15 * * * *

# Every hour at minute 0
0 * * * *

# Every 6 hours
0 */6 * * *

# Daily at 2 AM
0 2 * * *
```

## Logging Configuration

### Log Locations

**Komodo Core Logs:**
- **Location**: TrueNAS app logs via web UI
- **Path**: `/mnt/apps01/appdata/komodo/logs/`
- **Retention**: 30 days (configurable)

**Stack Deployment Logs:**
- **Location**: Available in Komodo web UI for each stack
- **Real-time**: Monitor during deployment via UI
- **History**: Previous deployment logs accessible

**Container Logs:**
- **Location**: Docker logging driver
- **Access**: `docker compose logs -f <service>`

### Monitoring Logs

**Real-time Stack Logs:**
```bash
# Specific stack logs
docker compose -f stacks/00-proxy/compose.yml logs -f

# All containers for a stack
docker compose -f stacks/20-harbor/compose.yml logs -f
```

**Komodo Core Logs:**
```bash
# Via TrueNAS CLI (if using external storage)
tail -f /mnt/apps01/appdata/komodo/logs/komodo.log

# Via Docker (if using compose)
docker logs -f komodo-core
```

## Directory Structure

### Required Directories
```bash
# Create required directories
sudo mkdir -p /mnt/apps01/appdata/{komodo,mongodb}
sudo chown -R apps:apps /mnt/apps01/appdata/
```

### Expected Layout
```
/mnt/apps01/appdata/
├── komodo/                 # Komodo Core data
│   ├── config/
│   └── logs/
└── mongodb/                # MongoDB data (if external)
    └── data/
```

## Initial Setup Checklist

### Prerequisites
- [ ] TrueNAS SCALE installed and configured
- [ ] Docker service enabled
- [ ] External network created: `docker network create proxy_network`
- [ ] Required directories created with proper permissions

### Komodo Installation
- [ ] Komodo Core installed as TrueNAS app
- [ ] MongoDB installed and configured (if using external)
- [ ] Web UI accessible at `http://barbary.in.hypyr.space:9120`

### Stack Configuration
- [ ] Proxy stack configured in Komodo UI
- [ ] Harbor stack configured in Komodo UI
- [ ] Environment variables set with actual values
- [ ] Deployment order: proxy first, then harbor

### Trigger Configuration
- [ ] Manual deployment tested for each stack
- [ ] GitHub webhook configured (optional)
- [ ] Periodic schedule configured (optional)

### Validation
- [ ] Both stacks deployed successfully
- [ ] Services accessible via configured domains
- [ ] Logs accessible through Komodo UI
- [ ] Webhook triggers working (if configured)

## Troubleshooting

### Common Issues

**Komodo Core won't start:**
- Check MongoDB connection
- Verify storage permissions
- Review TrueNAS app logs

**Stack deployment failed:**
- Check git repository access
- Verify environment variables in stack configuration
- Review deployment logs in Komodo UI
- Confirm Docker network exists

**Permission errors:**
- Ensure proper directory ownership
- Verify Docker socket access
- Check Komodo service permissions

### Debug Commands
```bash
# Test git access
git clone https://github.com/cpritchett/homelab.git /tmp/test-checkout

# Test Docker access
docker ps

# Test network
docker network ls | grep proxy_network

# Check Komodo status
docker ps | grep komodo
```

## Security Considerations

- Komodo stores environment variables securely in its database
- No secrets committed to git repository
- Git repository access uses read-only tokens
- Webhook secrets properly configured
- Log files contain no sensitive information
- Regular security updates for all components

## References

- [Komodo Documentation](https://komo.do)
- [TrueNAS SCALE Apps](https://www.truenas.com/docs/scale/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [GitHub Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks)