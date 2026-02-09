# 1Password Connect Migration Guide

This guide covers migrating from the `op-export` pattern (env file materialization) to 1Password Connect Server (dynamic secret access).

## What Changed

### Before (op-export pattern)
- Ran a job to pull secrets from 1Password and write to `/mnt/apps01/secrets/<stack>/*.env`
- Stacks mounted these env files
- Required tagging items with `stack:<name>`
- Secrets lived on disk as plaintext files

### After (Connect pattern)
- 1Password Connect Server runs as a persistent service
- Stacks can fetch secrets at runtime via HTTP API
- No env files on disk (secrets stay in memory)
- Uses standard 1Password item format with `op://vault/item/field` references

## Migration Steps

### 1. Deploy 1Password Connect

Follow [stacks/platform/secrets/op-connect/README.md](../platform/secrets/op-connect/README.md):

1. Generate Connect server credentials on your workstation
2. Copy to TrueNAS at `/mnt/apps01/secrets/op/1password-credentials.json`
3. Deploy `op-connect` stack via Komodo
4. Verify both services are healthy

### 2. Restructure 1Password Items

Old format (tagged env files):
```
Item: "authentik.env" (tag: stack:authentik)
Fields:
  AUTHENTIK_SECRET_KEY=xxxxx
  AUTHENTIK_POSTGRESQL__PASSWORD=yyyyy
```

New format (standard items with stacks tag):
```
Item: "authentik-stack" (tag: stacks)
Fields:
  secret_key: xxxxx
  postgres_password: yyyyy
  bootstrap_email: admin@example.com
  bootstrap_password: xxxxx
```

Reference in templates as: `op://homelab/authentik-stack/secret_key`

### 3. Create Shared Connect Token

Generate one token and store it as a Swarm secret for all stacks:

```bash
# On your workstation
op connect token create homelab-stacks --server homelab-truenas --vault homelab

# Store as Swarm secret
echo "<token>" | ssh truenas "docker secret create op_connect_token -"

# Verify
ssh truenas "docker secret ls | grep op_connect_token"
```

All stacks will reference this shared `op_connect_token` secret - no need to manage tokens per-stack.

### 4. Choose Migration Pattern

Pick one based on your stack's needs:

#### Pattern A: op inject (Template-Based)

Best for: Stacks that already use env files

1. Create config template with `op://` references
2. Add init container or wrapper script that runs `op inject`
3. Mount templated output into main container

See: [docs/deployment/AUTHENTIK_MIGRATION.md](../../docs/deployment/AUTHENTIK_MIGRATION.md) for full example

#### Pattern B: Direct SDK (Code Integration)

Best for: Custom apps you control

Use 1Password Connect SDKs to fetch secrets in your application code:

- [Go SDK](https://github.com/1Password/connect-sdk-go)
- [Python SDK](https://github.com/1Password/connect-sdk-python)
- [JavaScript SDK](https://github.com/1Password/connect-sdk-js)

#### Pattern C: Sidecar (Periodic Refresh)

Best for: Apps that need files on disk but support file watching

Deploy a sidecar that periodically fetches secrets and writes them to a shared volume.

### 5. Update Stack Compose Files

Remove old env_file mounts:
```yaml
# OLD
services:
  app:
    env_file:
      - /mnt/apps01/secrets/mystack/app.env
```

Add Connect network and inject pattern:
```yaml
# NEW
services:
  secrets-init:
    image: 1password/op:2
    environment:
      OP_CONNECT_HOST: http://op-connect-api:8080
      OP_CONNECT_TOKEN_FILE: /run/secrets/op_connect_token
    secrets:
      - op_connect_token
    volumes:
      - /mnt/apps01/configs/mystack:/templates:ro
      - secrets-volume:/secrets
    networks:
      - op-connect
    command: >
      sh -c "
      export OP_CONNECT_TOKEN=$(cat /run/secrets/op_connect_token)
      op inject -i /templates/env.template -o /secrets/app.env
      "
    restart: "no"
  
  app:
    env_file:
      - secrets-volume/app.env
    volumes:
      - secrets-volume:/secrets:ro
    depends_on:
      secrets-init:
        condition: service_completed_successfully

networks:
  op-connect:
    name: op-connect_op-connect
    external: true

volumes:
  secrets-volume:

secrets:
  op_connect_token:
    external: true
```

### 6. Test Migration

1. Deploy updated stack
2. Verify secrets are injected correctly
3. Check app functionality
4. Monitor logs for secret access errors

### 7. Clean Up Old Pattern

Once all stacks are migrated:

1. Stop `op-export` stack in Komodo
2. Remove old env files: `rm -rf /mnt/apps01/secrets/*/`
3. Remove stack tags from 1Password items (no longer needed)
4. Update documentation to reference new pattern

## Troubleshooting

### "cannot connect to op-connect-api"
- Ensure op-connect stack is healthy: `docker service ls | grep op-connect`
- Verify Swarm secret exists: `docker secret ls | grep op_connect_token`
- Check token has vault access (from your workstation with the token file)
- Regenerate token if expired and update Swarm secret:
  ```bash
  docker secret rm op_connect_token
  echo "<new-token>" | docker secret create op_connect_token -
  ```
### "invalid token" errors
- Verify token has vault access: `op connect vault list --token <token>`
- Regenerate token if expired
- Ensure token is correctly set in Komodo secrets

### "vault/item not found"
- Verify item exists: `op item get <item-name> --vault <vault>`
- Check vault name in `op://` reference matches actual vault
- Ensure Connect server was created with access to that vault

### Secrets not updating
- Connect sync service may be failing: `docker service logs op-connect_op-connect-sync`
- Restart stack to force re-injection
- For sidecar pattern, check refresh interval

## Rollback Plan

If you need to rollback:

1. Re-deploy `op-export` stack
2. Run export job to regenerate env files
3. Revert compose files to use `env_file` mounts
4. Keep Connect stack running (doesn't hurt) or remove it

## References

- [1Password Connect Documentation](https://developer.1password.com/docs/connect/)
- [op inject Reference](https://developer.1password.com/docs/cli/reference/commands/inject/)
- [stacks/platform/secrets/op-connect/README.md](../platform/secrets/op-connect/README.md)
- [ADR-0004: Secrets Management](../../docs/adr/ADR-0004-secrets-management.md)
