# 1Password Connect Server Stack

Runs 1Password Connect Server to provide HTTP API access to 1Password secrets for all Docker stacks.

## Architecture

1Password Connect consists of two services:
- **connect-api**: HTTP API server (port 8080) for secret access
- **connect-sync**: Synchronization service that keeps secrets up-to-date from 1Password

Both services share a data volume and communicate via internal bus protocol.

## Quick Start

### 1. Generate Connect Server Credentials

On your **workstation** (where `op` CLI is installed and authenticated):

```bash
# List your vaults to get the vault ID
op vault list

# Create a Connect server (replace with your vault ID/name)
op connect server create homelab-truenas --vaults homelab

# This outputs a credentials JSON - save it as 1password-credentials.json
```

The command will output a JSON credentials file. Save this output.

### 2. Copy Credentials to TrueNAS

```bash
# Create the secrets directory on TrueNAS (if not exists)
ssh truenas "mkdir -p /mnt/apps01/secrets/op"

# Copy the credentials file to TrueNAS
scp 1password-credentials.json truenas:/mnt/apps01/secrets/op/

# Set appropriate permissions
ssh truenas "chown 1701:1702 /mnt/apps01/secrets/op/1password-credentials.json"
ssh truenas "chmod 600 /mnt/apps01/secrets/op/1password-credentials.json"
```

**Important:** Keep the credentials file secure. It provides full access to the configured vaults. Do not commit it to git.

Optional helper (run on TrueNAS): `stacks/scripts/set-host-permissions.sh`

### 3. Deploy via Komodo

1. Add this stack to Komodo from GitHub (`stacks/platform/secrets/op-connect`)
2. Configure environment variables (optional - defaults are usually fine)
3. Deploy the stack
4. If you change the container user (defaults overridden to `1701:1702` in compose), ensure the shared data volume is owned by that UID/GID.

### 4. Verify Deployment

Check that both services are healthy:

```bash
# On TrueNAS
docker service ls | grep op-connect
docker service logs op-connect_op-connect-api
docker service logs op-connect_op-connect-sync
```

**Note on API Access:** The Connect API is only exposed via the overlay network and is not accessible on the TrueNAS host network. To verify the health endpoint, you can:

1. Run the curl command from within a container on the `op-connect` network:
   ```bash
   docker run --rm --network op-connect_op-connect curlimages/curl:latest \
     http://op-connect-api:8080/health
   ```

2. Or exec into one of the op-connect containers:
   ```bash
   # Get container ID
   docker ps | grep op-connect-api
   # Exec into container
   docker exec -it <container-id> wget -qO- http://localhost:8080/health
   ```

You should see a healthy response from the API.

## Using Connect in Other Stacks

### Method 1: Direct API Access (for custom apps)

Your applications can query the Connect API directly using the shared Swarm secret:

```yaml
services:
  myapp:
    image: myapp:latest
    environment:
      OP_CONNECT_HOST: http://op-connect-api:8080
      OP_CONNECT_TOKEN_FILE: /run/secrets/op_connect_token
    secrets:
      - op_connect_token
    networks:
      - op-connect
    # Your app uses 1Password SDK to fetch secrets at runtime

networks:
  op-connect:
    external: true
    name: op-connect_op-connect
```

### Method 2: `op inject` Pattern (Recommended)

Use `op inject` to template secrets into config files at container startup with the shared Swarm secret:

```yaml
services:
  myapp:
    image: 1password/op:2  # Use op CLI image as base or install in your image
    environment:
      OP_CONNECT_HOST: http://op-connect-api:8080
      OP_CONNECT_TOKEN_FILE: /run/secrets/op_connect_token
    secrets:
      - op_connect_token
    volumes:
      - ./config.template.yaml:/config.template.yaml:ro
      - /mnt/apps01/appdata/myapp:/data
    networks:
      - op-connect
    command: >
      sh -c "
      export OP_CONNECT_TOKEN=$(cat /run/secrets/op_connect_token) &&
      op inject -i /config.template.yaml -o /data/config.yaml &&
      exec myapp-binary --config /data/config.yaml
      "

secrets:
  op_connect_token:
    external: true

networks:
  op-connect:
    external: true
    name: op-connect_op-connect
```

### Method 3: Periodic Secret Sync

For applications that can't use `op inject` directly, use a sidecar to periodically sync secrets:

```yaml
services:
  secret-sync:
    image: 1password/op:2
    environment:
      OP_CONNECT_HOST: http://op-connect-api:8080
      OP_CONNECT_TOKEN_FILE: /run/secrets/op_connect_token
    secrets:
      - op_connect_token
    volumes:
      - shared-secrets:/secrets
    networks:
      - op-connect
    command: >
      sh -c "
      export OP_CONNECT_TOKEN=$$(cat /run/secrets/op_connect_token) &&
      while true; do
        op read 'op://homelab/myapp/secret' > /secrets/SECRET_KEY &&
        op read 'op://homelab/myapp/db-pass' > /secrets/DB_PASSWORD &&
        sleep 300
      done
      "
    restart: unless-stopped

  myapp:
    image: myapp:latest
    volumes:
      - shared-secrets:/secrets:ro
    environment:
      SECRET_KEY_FILE: /secrets/SECRET_KEY
      DB_PASSWORD_FILE: /secrets/DB_PASSWORD
    depends_on:
      - secret-sync

volumes:
  shared-secrets:

secrets:
  op_connect_token:
    external: true

networks:
  op-connect:
    external: true
    name: op-connect_op-connect
```

## Creating Connect Token

Connect tokens are separate from the server credentials and can be scoped to specific vaults/items.

For homelab use, **create one token and store it as a Swarm secret** for all stacks to use:

```bash
# On your workstation - create one token
op connect token create homelab-stacks --server homelab-truenas --vault homelab

# Store as Docker Swarm secret on TrueNAS
echo "<token-from-above>" | ssh truenas "docker secret create op_connect_token -"

# Verify
ssh truenas "docker secret ls | grep op_connect"
```

**Note:** The token is stored as a Docker Swarm secret (`op_connect_token`), which is encrypted at rest and only accessible to services that explicitly mount it. For homelab use, one shared token is sufficient. In production, you might create separate tokens per stack for granular revocation.

Now all stacks can reference this shared secret instead of storing tokens individually in Komodo.

## Security Considerations

1. **Credentials file**: The `1password-credentials.json` file grants full access to configured vaults. Protect it with 600 permissions and never commit to git.

2. **Connect tokens**: Create separate tokens for different stacks/purposes. This allows you to revoke access granularly if needed.

3. **Network isolation**: The Connect API is only exposed on the overlay network. Consider restricting which stacks can attach to the `op-connect` network.

4. **Swarm secrets**: For extra security in production, store the credentials file as a Docker Swarm secret:
   ```bash
   docker secret create op-credentials /mnt/apps01/secrets/op/1password-credentials.json
   ```
   Then update compose.yaml to use:
   ```yaml
   secrets:
     - op-credentials
   
   secrets:
     op-credentials:
       external: true
   ```

## Troubleshooting

### API not responding
```bash
docker service logs op-connect_op-connect-api --tail 100
```

Check for:
- Credentials file not found or invalid
- Vault access denied
- Network connectivity issues

### Sync service failing
```bash
docker service logs op-connect_op-connect-sync --tail 100
```

Common issues:
- Cannot reach 1Password servers (check internet connectivity)
- Credentials expired or revoked
- Vault permissions changed

### "vault not found" errors

Ensure the vault ID/name used when creating the server matches the vaults you're trying to access. List configured vaults:

```bash
op connect vault list --server homelab-truenas
```

## Migration from op-export

To migrate from the old `op-export` pattern:

1. Deploy this Connect stack first
2. Update dependent stacks to use `op inject` or Connect API pattern
3. Create Connect tokens for stacks that need them
4. Test each stack's secret access
5. Once all stacks are migrated, remove the `op-export` stack

Example migration for authentik stack - see `stacks/platform/auth/authentik/README.md` for updated instructions.

## References

- [1Password Connect Documentation](https://developer.1password.com/docs/connect/)
- [1Password Connect SDKs](https://developer.1password.com/docs/connect/connect-sdks/)
- [ADR-0004: Secrets Management](../../../../docs/adr/ADR-0004-secrets-management.md)
- [ADR-0022: Komodo-Managed Stacks](../../../../docs/adr/ADR-0022-truenas-komodo-stacks.md)
