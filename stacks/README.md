# NAS Deployment Stacks

This directory contains deployment manifests for containerized workloads running on NAS nodes (non-Kubernetes infrastructure) using Komodo Core and Periphery.

## Purpose

NAS nodes in this homelab (TrueNAS SCALE) run containerized services outside of the Kubernetes cluster. These deployments use Docker Compose orchestration with Komodo for deployment automation and 1Password for secret management.

## Organization

### Stack Definitions
- `00-proxy/` - Caddy reverse proxy (provides proxy_network)
- `20-harbor/` - Harbor container registry (depends on proxy)

Stack deployment order is defined in `stacks/registry` using explicit dependencies for topological sorting.

### Infrastructure Utilities
- `_bin/` - Deployment scripts and utilities (not a stack)
- `_system/` - TrueNAS system integration hooks (init scripts, cron jobs)

Directories prefixed with underscore are infrastructure components, not stacks.

## Komodo Integration

This stack layout is designed for Komodo Core (TrueNAS app) with Periphery executing deployments:

- **No secrets in git**: Only `.env.tpl` files with `op://` references
- **1Password injection**: Secrets rendered at deploy time via service account
- **Sparse checkout**: Only `stacks/` and `docs/` synced to NAS
- **Dependency management**: Automatic topological sorting of stack deployments

See [docs/STACKS_KOMODO.md](../docs/STACKS_KOMODO.md) for complete setup and usage guide.

## Network Architecture

All services communicate via the `proxy_network` Docker network:

1. **Proxy** (00-proxy) - Caddy reverse proxy, creates proxy_network
2. **Harbor** (20-harbor) - Container registry, connects to proxy_network

### Service Discovery

Services are discovered via Docker labels on the `proxy_network`:

```yaml
labels:
  caddy: "myapp.in.hypyr.space"
  caddy.reverse_proxy: "{{upstreams 8080}}"
```

No host port mappings required (except for Caddy itself on 80/443).

## Quick Start

```bash
# Deploy all stacks in dependency order
./_bin/deploy-all

# Deploy individual stack
./_bin/deploy-stack /path/to/stack/directory

# Sync from git and deploy (Komodo Periphery command)
./_bin/sync-and-deploy
```

## Adding New Stacks

1. Create `stacks/NN-stackname/` directory
2. Add entry to `stacks/registry` with dependencies
3. Create `compose.yml` with proper Caddy labels
4. Create `.env.tpl` with `op://` secret references
5. Copy `render-env.sh` from existing stack

See [docs/STACKS_KOMODO.md](../docs/STACKS_KOMODO.md) for detailed instructions.

## Separation from Kubernetes

- **Kubernetes workloads** → `kubernetes/` directory (managed by Flux)
- **NAS workloads** → `stacks/` directory (this directory)
- **Infrastructure provisioning** → `infra/` directory

## References

- [Komodo Deployment Guide](../docs/STACKS_KOMODO.md) - Complete setup instructions
- [Repository Structure](../requirements/workflow/repository-structure.md) - Governance documentation
