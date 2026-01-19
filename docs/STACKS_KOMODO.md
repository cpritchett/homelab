# Komodo Stack Deployment Guide

This document explains how to deploy containerized stacks on TrueNAS SCALE using Komodo Core and Periphery with 1Password secret injection.

## Architecture Overview

- **Komodo Core**: Installed as a TrueNAS app, provides the web UI and orchestration
- **Komodo Periphery**: Runs on the NAS host, executes deployment commands
- **1Password**: Stores all secrets, injected at deploy time via service account
- **Git Sparse Checkout**: Only `stacks/` and `docs/` directories are synced to NAS

## Secret Management

### No Secrets in Git
- All secrets remain in 1Password vaults
- Only `.env.tpl` files with `op://` references are committed
- `.env` files are generated at deploy time and never committed

### 1Password Integration
- Service account token stored at `/mnt/apps01/appdata/secrets/1password/op_service_account_token`
- Secrets cached in `/mnt/apps01/appdata/secrets/1password/op-cache/` for performance
- `op-inject` script runs 1Password CLI in a container with proper user permissions

## Stack Structure

### Directory Layout
```
stacks/
├── _bin/                    # Deployment scripts (not a stack)
│   ├── op-inject           # 1Password CLI wrapper
│   ├── deploy-stack        # Deploy single stack
│   ├── deploy-all          # Deploy all stacks in order
│   └── sync-and-deploy     # Git sync + deploy all
├── registry                # Stack registry (deployment order)
├── 00-proxy/              # Caddy reverse proxy
│   ├── compose.yml
│   ├── .env.tpl
│   └── render-env.sh
└── 20-harbor/             # Harbor container registry
    ├── compose.yml
    ├── .env.tpl
    └── render-env.sh
```

### Stack Naming Convention
- `00-proxy`: Core infrastructure (proxy, networking)
- `20-harbor`: Applications that depend on proxy
- Numbers indicate deployment order, names indicate function

## Deployment Process

### Primary: Komodo Periphery
Komodo Periphery is the **primary deployment mechanism** and should be configured to run:
```bash
/mnt/apps01/appdata/stacks/checkout/stacks/_bin/sync-and-deploy
```

**Komodo handles:**
- Scheduled deployments (replaces cron jobs)
- Deployment triggers (webhooks, manual, etc.)
- Deployment history and rollbacks
- Resource monitoring and alerts

### Failsafe: TrueNAS Init (Optional)
An optional TrueNAS init script exists at `stacks/_system/init/10-homelab-stacks.sh` as a failsafe bootstrap mechanism. This is **not the primary deployment method**.

**Use the init script only for:**
- Emergency bootstrap if Komodo is unavailable
- Initial system setup before Komodo is configured
- Testing deployment scripts

The init script:
- Runs `sync-and-deploy` in background with 300s timeout
- Logs to `/mnt/apps01/appdata/logs/stacks/bootstrap.log`
- Exits gracefully if `sync-and-deploy` is not found
- Does not interfere with Komodo operations

### Manual Deployment
```bash
# Deploy all stacks
cd /mnt/apps01/appdata/stacks/checkout/stacks
./_bin/deploy-all

# Deploy single stack
./_bin/deploy-stack /path/to/stack/directory

# Sync repo and deploy
./_bin/sync-and-deploy
```

## Stack Registry Format

The `stacks/registry` file defines deployment order and dependencies:
```
# Format: stack_name:path:depends_on (comma-separated deps, empty for none)
proxy:00-proxy:
harbor:20-harbor:proxy
```

- Simple colon-separated format (no TOML/JSON parsing required)
- Topological sort ensures dependencies deploy first
- Cycle detection prevents infinite loops

## Network Architecture

### External Networks
- `proxy_network`: Shared network for all stacks
- Must be created manually: `docker network create proxy_network`

### Service Discovery
- Caddy discovers services via Docker labels
- No host port mappings required (except for Caddy itself)
- All services route through Caddy on `proxy_network`

## Adding a New Stack

1. **Create stack directory**: `stacks/NN-stackname/`
2. **Add to registry**: Update `stacks/registry` with dependencies
3. **Create compose.yml**: Define services with proper labels
4. **Create .env.tpl**: Define secrets with `op://` references
5. **Create render-env.sh**: Copy from existing stack
6. **Test deployment**: Run `deploy-stack` manually first

### Example Stack Structure
```bash
mkdir stacks/30-myapp
cd stacks/30-myapp

# Create compose.yml with Caddy labels
cat > compose.yml << 'EOF'
services:
  myapp:
    image: myapp:latest
    networks:
      - proxy_network
    labels:
      caddy: myapp.in.hypyr.space
      caddy.reverse_proxy: "{{upstreams 8080}}"
networks:
  proxy_network:
    external: true
EOF

# Create .env.tpl with 1Password references
cat > .env.tpl << 'EOF'
MYAPP_SECRET=op://homelab/myapp/secret
EOF

# Copy render-env.sh from another stack
cp ../20-harbor/render-env.sh .

# Add to registry
echo "myapp:30-myapp:proxy" >> ../registry
```

## Troubleshooting

### Common Issues
- **Permission errors**: Ensure `op-inject` runs with correct user ID
- **Network errors**: Verify `proxy_network` exists
- **Secret errors**: Check 1Password service account token
- **Dependency errors**: Verify registry format and dependencies

### Debugging Commands
```bash
# Check stack status
sudo docker compose ps

# View logs
sudo docker compose logs -f

# Test 1Password injection
/mnt/apps01/appdata/bin/op-inject inject .env.tpl

# Validate registry
stacks/_bin/deploy-all --dry-run  # (if implemented)
```

### Log Locations
- Komodo logs: TrueNAS app logs
- Container logs: `sudo docker compose logs`
- 1Password cache: `/mnt/apps01/appdata/secrets/1password/op-cache/`

## Security Considerations

- Service account token has read-only access to specific vaults
- Secrets are never written to disk permanently
- All containers run as non-root users where possible
- Docker socket access is proxied and restricted
- TLS certificates managed automatically via Cloudflare DNS-01

## References

- [Komodo Documentation](https://komo.do)
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts)
- [Caddy Docker Labels](https://github.com/lucaslorentz/caddy-docker-proxy)
- [Harbor Installation Guide](https://goharbor.io/docs/latest/install-config/)