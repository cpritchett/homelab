# Stack Lifecycle Management

This document describes the operational lifecycle of containerized stacks deployed via Komodo on TrueNAS SCALE.

## Stack States

### Development
- Stack exists in `stacks/` directory with compose.yml
- Secrets defined in `.env.tpl` with 1Password references
- Not yet added to `stacks/registry`

### Deployed
- Stack listed in `stacks/registry` with dependencies
- Deployed via Komodo or manual `deploy-stack` script
- Services running and accessible via Caddy proxy

### Maintenance
- Stack temporarily stopped for updates or troubleshooting
- Configuration changes applied
- Services restarted

### Decommissioned
- Stack removed from `stacks/registry`
- Services stopped and containers removed
- Data volumes preserved for potential recovery

## Deployment Operations

### Adding a New Stack
1. Create stack directory: `stacks/NN-stackname/`
2. Define services in `compose.yml`
3. Create `.env.example` with required environment variables
4. Configure stack in Komodo UI with actual environment values
5. Test deployment via Komodo UI
6. Commit changes to repository

### Updating an Existing Stack
1. Modify `compose.yml` or `.env.example` as needed
2. Update environment variables in Komodo UI if required
3. Test changes locally if possible
4. Commit changes
5. Redeploy stack via Komodo UI

### Removing a Stack
1. Stop stack via Komodo UI
2. Delete stack configuration from Komodo
3. Archive stack directory to `stacks/_archive/` if needed
4. Clean up any external dependencies (networks, volumes)

## Troubleshooting

### Stack Won't Start
- Check dependencies are configured correctly in Komodo
- Verify environment variables are set in Komodo UI
- Check Docker network `proxy_network` exists
- Review container logs via Komodo UI or `docker compose logs -f`

### Service Not Accessible
- Verify Caddy labels in compose.yml
- Check service is on `proxy_network`
- Confirm DNS resolution for service domain
- Review Caddy proxy logs

### Deployment Failures
- Check git repository access in Komodo configuration
- Verify environment variables in Komodo stack settings
- Review deployment logs in Komodo UI
- Ensure sufficient disk space and resources

## Monitoring

### Health Checks
- Container status: `docker compose ps`
- Service logs: `docker compose logs -f <service>`
- Resource usage: `docker stats`
- Network connectivity: `docker network inspect proxy_network`

### Log Locations
- Stack deployment logs: Komodo UI for each stack
- Container logs: `docker compose logs`
- Komodo logs: TrueNAS app interface
- System logs: `/var/log/` on TrueNAS

## Best Practices

### Configuration Management
- Keep secrets in Komodo UI, never in git
- Use descriptive stack names with numeric prefixes for ordering
- Document dependencies clearly in stack descriptions
- Test changes on non-critical stacks first

### Resource Management
- Set appropriate resource limits in compose.yml
- Monitor disk usage for persistent volumes
- Use health checks where supported
- Implement graceful shutdown procedures

### Security
- Run containers as non-root users when possible
- Limit container capabilities and privileges
- Keep base images updated
- Audit environment variable access through Komodo logs

## Related Documentation

- [STACKS.md](STACKS.md) - Stack deployment overview
- [STACKS_KOMODO.md](STACKS_KOMODO.md) - Komodo integration guide
- [../komodo/KOMODO_SETUP.md](../komodo/KOMODO_SETUP.md) - Komodo installation