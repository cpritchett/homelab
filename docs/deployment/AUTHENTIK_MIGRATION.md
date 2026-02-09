# Authentik 1Password Migration Status

Status: Completed. Authentik is already migrated to the 1Password Connect `op inject` pattern in `stacks/platform/auth/authentik/compose.yaml`.

## Legacy Approach (env_file + op-export)

Before Connect, we used env files:

```yaml
services:
  authentik-server:
    env_file:
      - /mnt/apps01/secrets/authentik/authentik.env
```

This required running `op-export` as a separate job to materialize secrets to disk.

## Current Approach (op inject)

Authentik now injects secrets at startup using `secrets-init` + `op inject`, without the legacy `op-export` flow.

### Current Template Inputs

Current stack-managed templates:

```bash
AUTHENTIK_SECRET_KEY=op://homelab/authentik-stack/secret_key
AUTHENTIK_POSTGRESQL__PASSWORD=op://homelab/authentik-stack/postgres_password
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_BOOTSTRAP_PASSWORD=op://homelab/authentik-stack/bootstrap_password
AUTHENTIK_BOOTSTRAP_EMAIL=op://homelab/authentik-stack/bootstrap_email
```

Files:
- `stacks/platform/auth/authentik/env.template`
- `stacks/platform/auth/authentik/postgres.template`

### Current Runtime Pattern

See `stacks/platform/auth/authentik/compose.yaml` for authoritative configuration. Pattern summary:

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
      export OP_CONNECT_TOKEN=$(cat /run/secrets/op_connect_token)
      op inject -i /templates/authentik.template -o /secrets/authentik.env -f &&
      op inject -i /templates/postgres.template -o /secrets/postgres.env -f &&
      echo 'Secrets injected successfully'
      "
```

### Network + Secret Dependency

Add the external network:

```yaml
networks:
  op-connect:
    name: op-connect_op-connect
    external: true
  authentik:
    driver: overlay

secrets:
  op_connect_token:
    external: true
```

### Shared Connect Token

The Connect token is already stored as a Docker Swarm secret (`op_connect_token`). Just reference it in your compose file - no need to add anything in Komodo UI.

## Alternative: Direct SDK Integration

For custom apps, you can use 1Password Connect SDKs to fetch secrets at runtime without templating:

- [Go SDK](https://github.com/1Password/connect-sdk-go)
- [Python SDK](https://github.com/1Password/connect-sdk-python)
- [JavaScript SDK](https://github.com/1Password/connect-sdk-js)

This is cleaner but requires application code changes.

## Validation Checklist (Post-Migration)

- [x] `op-connect` stack deployed
- [x] Connect token present as Swarm secret: `op_connect_token`
- [x] Authentik templates use `op://homelab/authentik-stack/...` references
- [x] `secrets-init` injects both `authentik.env` and `postgres.env`
- [x] Legacy `op-export` dependency removed from Authentik stack
- [x] Deployment path documented in `docs/deployment/AUTHENTIK_DEPLOY.md`
