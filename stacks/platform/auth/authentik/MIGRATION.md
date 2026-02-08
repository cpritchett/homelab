# Authentik Stack with 1Password Connect Integration

Example showing how to use `op inject` to hydrate secrets from 1Password Connect at runtime.

## Traditional Approach (env_file)

Before Connect, we used env files:

```yaml
services:
  authentik-server:
    env_file:
      - /mnt/apps01/secrets/authentik/authentik.env
```

This required running `op-export` as a separate job to materialize secrets to disk.

## New Approach (op inject)

With 1Password Connect, we can inject secrets at container startup without pre-materializing to disk.

### Step 1: Create config template

Create `/mnt/apps01/configs/authentik/env.template`:

```bash
AUTHENTIK_SECRET_KEY=op://homelab/authentik/secret_key
AUTHENTIK_POSTGRESQL__PASSWORD=op://homelab/authentik/postgres_password
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_BOOTSTRAP_PASSWORD=op://homelab/authentik/bootstrap_password
AUTHENTIK_BOOTSTRAP_TOKEN=op://homelab/authentik/bootstrap_token
```

### Step 2: Add op inject init container

Modify your compose.yaml to use an init container pattern or entrypoint wrapper:

```yaml
services:
  authentik-server:
    image: ghcr.io/goauthentik/server:latest
    # Option A: Multi-stage with op installed in image (requires custom Dockerfile)
    # Option B: Use init container pattern below

  # Init container that runs once and writes secrets
  authentik-secrets-init:
    image: 1password/op:2
    volumes:
      - /mnt/apps01/configs/authentik:/templates:ro
      - authentik-secrets:/secrets
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
      op inject -i /templates/env.template -o /secrets/authentik.env &&
      echo 'Secrets injected successfully'
      "
    restart: "no"
    depends_on:
      - postgresql
      - redis

  authentik-server:
    image: ghcr.io/goauthentik/server:latest
    env_file:
      - authentik-secrets/authentik.env  # Now sourced from init container
    volumes:
      - authentik-secrets:/secrets:ro
    depends_on:
      authentik-secrets-init:
        condition: service_completed_successfully
```

### Step 3: Connect to op-connect network

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

### Step 4: Use shared Connect token

The Connect token is already stored as a Docker Swarm secret (`op_connect_token`). Just reference it in your compose file - no need to add anything in Komodo UI.

## Alternative: Direct SDK Integration

For custom apps, you can use 1Password Connect SDKs to fetch secrets at runtime without templating:

- [Go SDK](https://github.com/1Password/connect-sdk-go)
- [Python SDK](https://github.com/1Password/connect-sdk-python)
- [JavaScript SDK](https://github.com/1Password/connect-sdk-js)

This is cleaner but requires application code changes.

## Migration Checklist

- [ ] Deploy op-connect stack
- [ ] Create config templates with `op://` references
- [ ] Generate Connect token for this stack
- [ ] Update compose.yaml to use init container pattern
- [ ] Test secret injection
- [ ] Remove old env file mounts
- [ ] Clean up `/mnt/apps01/secrets/authentik/` files
