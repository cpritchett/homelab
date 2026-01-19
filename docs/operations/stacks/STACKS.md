# Stack Deployment Overview

This directory contains containerized application stacks deployed on TrueNAS SCALE via Komodo orchestration.

## Quick Start

**For complete setup and deployment instructions, see [STACKS_KOMODO.md](STACKS_KOMODO.md).**

## Current Stacks

- **00-proxy**: Caddy reverse proxy + docker-socket-proxy (terminates 80/443)
- **20-harbor**: Harbor container registry (routed via Caddy labels)

## Key Concepts

### Environment Management
- All environment variables configured in Komodo UI
- `.env.example` files show required variables with safe placeholders
- No secrets committed to git repository

### Deployment Order
- Managed through Komodo stack dependencies
- Proxy stack deployed first (creates proxy_network)
- Harbor stack deployed second (connects to proxy_network)

### Network Architecture
- All services join `proxy_network`
- Caddy discovers services via Docker labels
- No host port mappings required (except Caddy itself)

## Documentation

- **[STACKS_KOMODO.md](STACKS_KOMODO.md)** - Complete deployment guide with Komodo integration
- **[lifecycle.md](lifecycle.md)** - Stack lifecycle management procedures
- **[../komodo/KOMODO_SETUP.md](../komodo/KOMODO_SETUP.md)** - Komodo installation and configuration

## Related

- **Stack Definitions**: `stacks/NN-stackname/` - Individual stack configurations
- **Environment Examples**: `.env.example` files in each stack directory
