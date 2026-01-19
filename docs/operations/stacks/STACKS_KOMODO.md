# Komodo Stack Deployment Guide

This document explains how to deploy containerized stacks on TrueNAS SCALE using Komodo Core for orchestration and management.

## Architecture Overview

- **Komodo Core**: Installed as a TrueNAS app, provides the web UI and orchestration
- **Git Integration**: Komodo pulls compose files directly from this repository
- **Environment Management**: Secrets and configuration managed through Komodo UI
- **No External Dependencies**: No 1Password or custom deployment scripts required

## Stack Management

### Repository Structure
```
stacks/
├── 00-proxy/              # Caddy reverse proxy
│   ├── compose.yml
│   └── .env.example
└── 20-harbor/             # Harbor container registry
    ├── compose.yml
    └── .env.example
```

### Stack Configuration
- **compose.yml**: Docker Compose service definitions with Caddy labels
- **.env.example**: Example environment variables with safe placeholders
- **No secrets in git**: All sensitive values configured in Komodo UI

## Deployment Process

### Komodo Stack Configuration

For each stack, create a Komodo "Stack" with these settings:

**Stack Name**: `proxy` (or `harbor`)
**Git Repository**: `https://github.com/cpritchett/homelab.git`
**Git Branch**: `main`
**Compose File Path**: `stacks/00-proxy/compose.yml` (adjust for each stack)

**Environment Variables** (configured in Komodo UI):
- Copy from `.env.example` file in each stack directory
- Replace placeholder values with actual secrets/configuration
- Komodo securely stores and injects these at runtime

### Deployment Order

Deploy stacks in dependency order:
1. **proxy** (00-proxy) - Creates proxy_network, no dependencies
2. **harbor** (20-harbor) - Depends on proxy_network being available

### Manual Deployment
Stacks can be deployed individually through the Komodo web UI:
1. Navigate to **Stacks** → Select stack
2. Click **Deploy** or **Redeploy**
3. Monitor deployment logs in real-time

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
2. **Create compose.yml**: Define services with proper labels
3. **Create .env.example**: Define required environment variables with safe placeholders
4. **Configure in Komodo**: Create new stack in Komodo UI with actual environment values
5. **Test deployment**: Deploy via Komodo UI and verify functionality

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

# Create .env.example with safe placeholders
cat > .env.example << 'EOF'
MYAPP_SECRET=your_secret_here
MYAPP_DATABASE_URL=postgresql://user:pass@host:5432/db
EOF
```

## Troubleshooting

### Common Issues
- **Permission errors**: Check Docker daemon access in Komodo configuration
- **Network errors**: Verify `proxy_network` exists: `docker network ls`
- **Environment errors**: Check environment variables in Komodo stack configuration
- **Image pull errors**: Verify image names and registry access

### Debugging Commands
```bash
# Check stack status
docker compose -f stacks/00-proxy/compose.yml ps

# View logs
docker compose -f stacks/00-proxy/compose.yml logs -f

# Test network connectivity
docker network inspect proxy_network

# Check Komodo logs
# (Available through TrueNAS app interface)
```

### Log Locations
- Komodo logs: TrueNAS app logs interface
- Container logs: `docker compose logs`
- Stack deployment logs: Available in Komodo UI

## Security Considerations

- Environment variables stored securely in Komodo database
- No secrets committed to git repository
- All containers run as non-root users where possible
- Docker socket access managed by Komodo with appropriate permissions
- TLS certificates managed automatically via Cloudflare DNS-01

## References

- [Komodo Documentation](https://komo.do)
- [Caddy Docker Labels](https://github.com/lucaslorentz/caddy-docker-proxy)
- [Harbor Installation Guide](https://goharbor.io/docs/latest/install-config/)