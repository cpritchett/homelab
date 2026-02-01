# ADR-0032: 1Password Connect for Docker Swarm Secrets

## Status
Accepted

## Context

Docker stacks on TrueNAS previously used an `op-export` container pattern that materialized secrets from 1Password to disk as env files (mounted at `/mnt/apps01/secrets/<stack>/*.env`). This approach had several issues:

1. **Reliability**: Container-based export jobs were difficult to orchestrate correctly in Komodo
2. **Security**: Secrets lived on disk as plaintext files
3. **Staleness**: Secrets were only refreshed when the export job ran
4. **Complexity**: Required custom tagging (`stack:<name>`) and export scripts
5. **No Swarm integration**: Didn't leverage Docker Swarm's native secret management

With TrueNAS now running Komodo beta in full Swarm mode, we have access to:
- Docker Swarm secrets (encrypted at rest, mounted at runtime)
- Overlay networks for service-to-service communication
- Service dependencies and health checks

1Password Connect Server provides an HTTP API for dynamic secret access, which is better suited to Swarm deployments than pre-materialized env files.

## Decision

1. **Deploy 1Password Connect Server** as a persistent Swarm stack (`stacks/platform/secrets/op-connect`)
   - Two services: `connect-api` (HTTP API) and `connect-sync` (synchronization)
   - Uses server credentials file mounted from host: `/mnt/apps01/secrets/op/1password-credentials.json`
   - Runs on `op-connect` overlay network, accessible to other stacks

2. **Store one Connect token as a shared Swarm secret**: `op_connect_token`
   - Single token provides access to all vaults/items (sufficient for homelab)
   - Encrypted at rest by Swarm
   - Only accessible to services that explicitly mount it
   - Simplifies token management (one token, not per-stack)

3. **Use `op inject` pattern for secret hydration**:
   - Each stack includes a `secrets-init` service that runs once on startup
   - Reads `op://homelab/item/field` references from template files
   - Uses `op inject` to resolve secrets and write env files to shared volumes
   - Main application services depend on `secrets-init` completion
   - Secrets never touch the host filesystem

4. **Restructure 1Password items**:
   - Old: Items named `<stack>.env` with fields like `KEY=value` (tagged with `stack:<name>`)
   - New: Standard items named `<stack>` with normal field labels (no tagging needed)
   - References use format: `op://homelab/<item>/<field>`

5. **Retire the op-export pattern**:
   - Remove `stacks/platform/secrets/op-export` stack
   - Remove old env files from `/mnt/apps01/secrets/`
   - Update all stack compose files to use new pattern

## Implementation

### Stack Pattern

All stacks follow this structure:

```yaml
services:
  secrets-init:
    image: 1password/op:2
    environment:
      OP_CONNECT_HOST: http://op-connect-api:8080
      OP_CONNECT_TOKEN_FILE: /run/secrets/op_connect_token
    secrets:
      - op_connect_token
    volumes:
      - ./env.template:/templates/app.template:ro
      - app-secrets:/secrets
    networks:
      - op-connect
    command: >
      sh -c "
      export OP_CONNECT_TOKEN=$$(cat /run/secrets/op_connect_token) &&
      op inject -i /templates/app.template -o /secrets/app.env &&
      echo 'Secrets injected successfully'
      "
    restart: "no"

  app:
    env_file:
      - app-secrets/app.env
    volumes:
      - app-secrets:/secrets:ro
    depends_on:
      secrets-init:
        condition: service_completed_successfully

networks:
  op-connect:
    external: true
    name: op-connect_op-connect

volumes:
  app-secrets:

secrets:
  op_connect_token:
    external: true
```

### Updated Stacks

- `stacks/platform/auth/authentik` — Authentik + Postgres secrets via op inject
- `stacks/platform/backups/restic` — Restic repository credentials via op inject
- `stacks/platform/cicd/forgejo` — Forgejo + Postgres secrets via op inject
- `stacks/platform/cicd/woodpecker` — Woodpecker agent + OAuth secrets via op inject

### Setup Process

1. Generate Connect server credentials on workstation:
   ```bash
   op connect server create homelab-truenas --vaults homelab
   ```

2. Copy to TrueNAS: `/mnt/apps01/secrets/op/1password-credentials.json`

3. Create and store shared token as Swarm secret:
   ```bash
   op connect token create homelab-stacks --server homelab-truenas --vault homelab
   echo "<token>" | ssh truenas "docker secret create op_connect_token -"
   ```

4. Deploy `op-connect` stack via Komodo

5. Deploy/update application stacks with new pattern

## Consequences

### Positive

- ✅ **Dynamic secrets**: No pre-materialization needed, Connect Server stays in sync with 1Password
- ✅ **Swarm-native**: Leverages encrypted secrets, overlay networks, service dependencies
- ✅ **Security**: Secrets never touch host filesystem (except credentials file), only in container memory
- ✅ **Simplicity**: One shared token, standard 1Password item format, no custom tagging
- ✅ **Reliability**: Init container pattern is simpler and more deterministic than background export jobs
- ✅ **Flexibility**: Supports multiple patterns (inject, SDK, sidecar) for different app needs

### Negative

- ⚠️ **New dependency**: Requires Connect Server running for stacks to start
- ⚠️ **Token rotation complexity**: Rotating the shared token requires updating Swarm secret (can be automated)
- ⚠️ **Network overhead**: Init containers add minimal startup time for secret injection
- ⚠️ **Migration effort**: All existing stacks need compose file updates and 1Password item restructuring

### Neutral

- 📝 **1Password subscription requirement**: Already required for op-export pattern (no change)
- 📝 **Init container pattern**: Industry-standard pattern, well-understood
- 📝 **Template files**: Requires maintaining `env.template` files in stack directories (similar to `.env.example`)

## Migration Path

1. Deploy `op-connect` stack alongside existing `op-export`
2. Migrate stacks incrementally (test each before proceeding)
3. Restructure 1Password items as stacks are migrated
4. Once all stacks migrated, remove `op-export` and clean up old env files

## Security Considerations

1. **Credentials file**: `/mnt/apps01/secrets/op/1password-credentials.json` grants full vault access
   - Protected with 600 permissions
   - Never committed to git
   - Backed up separately from regular backups

2. **Shared token**: Stored as Swarm secret, encrypted at rest
   - Only accessible to services that mount it
   - For homelab, one token is sufficient
   - Production might use per-stack tokens for granular revocation

3. **Network isolation**: `op-connect` network uses overlay driver
   - Only stacks that need secrets attach to it
   - API not exposed outside Swarm

4. **Secret rotation**: 
   - Credentials file: Regenerate server, copy new file, restart op-connect
   - Token: Create new token, update Swarm secret, restart dependent stacks

## Automation

Setup script provided: `stacks/scripts/setup-op-connect.sh`
- Generates server credentials
- Copies to TrueNAS
- Creates and stores shared Swarm secret
- One-command setup from workstation

## Links

- [ADR-0004: Secrets Management with 1Password](ADR-0004-secrets-management.md) — Foundation
- [ADR-0022: Komodo-Managed NAS Stacks](ADR-0022-truenas-komodo-stacks.md) — Deployment model
- [1Password Connect Documentation](https://developer.1password.com/docs/connect/)
- [stacks/platform/secrets/op-connect/README.md](../../stacks/platform/secrets/op-connect/README.md) — Implementation guide
- [stacks/docs/OP_CONNECT_MIGRATION.md](../../stacks/docs/OP_CONNECT_MIGRATION.md) — Migration guide
