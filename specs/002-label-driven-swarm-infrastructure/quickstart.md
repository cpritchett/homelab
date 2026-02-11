# Quickstart: Label-Driven Docker Swarm Infrastructure

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Prerequisites

- TrueNAS with Docker Swarm initialized
- 1Password Connect deployed and operational
- SSH access to TrueNAS host
- `op` CLI installed on workstation (for initial secret setup)

## Step 1: Bootstrap Infrastructure Tier

```bash
# SSH to TrueNAS
ssh truenas

# Run bootstrap script (deploys op-connect, Komodo, Caddy)
sudo ./scripts/truenas-init-bootstrap.sh

# Verify infrastructure services
docker service ls
# Expected: op-connect, komodo, caddy all showing 1/1
```

## Step 2: Deploy a New Service with Labels

Create a compose file following the label-driven pattern:

```yaml
# stacks/platform/myservice/compose.yaml
services:
  op-secrets:
    image: 1password/op:2@sha256:<digest>
    deploy:
      mode: replicated-job
      restart_policy:
        condition: none
    environment:
      OP_CONNECT_HOST: http://op-connect-api:8080
      OP_CONNECT_TOKEN_FILE: /run/secrets/op_connect_token
    secrets:
      - op_connect_token
    volumes:
      - ./env.template:/templates/myservice.template:ro
      - /mnt/apps01/appdata/myservice/secrets:/secrets
    networks:
      - op-connect
    command: >
      sh -ec "
      export OP_CONNECT_TOKEN=$$(cat /run/secrets/op_connect_token) &&
      op inject -i /templates/myservice.template -o /secrets/myservice.env -f &&
      echo 'Secrets injected successfully'
      "

  myservice:
    image: myapp:latest@sha256:<digest>
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: '1'
          memory: 512M
      labels:
        # Homepage Dashboard (REQUIRED)
        homepage.group: "Applications"
        homepage.name: "My Service"
        homepage.icon: "myservice.png"
        homepage.href: "https://myservice.in.hypyr.space"
        homepage.description: "Service description"

        # Caddy Reverse Proxy (REQUIRED if public)
        caddy: myservice.in.hypyr.space
        caddy.reverse_proxy: "{{upstreams 8080}}"
        caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

        # AutoKuma Monitoring (REQUIRED)
        kuma.myservice.http.name: "My Service"
        kuma.myservice.http.url: "https://myservice.in.hypyr.space/health"
        kuma.myservice.http.interval: "60"
        kuma.myservice.http.maxretries: "3"
    entrypoint: ["/bin/sh", "-c"]
    command: >
      "set -a && [ -f /secrets/myservice.env ] && . /secrets/myservice.env && set +a &&
       exec /app/start"
    volumes:
      - /mnt/apps01/appdata/myservice/secrets:/secrets:ro
    networks:
      - proxy_network
      - myservice_internal

networks:
  proxy_network:
    external: true
  op-connect:
    name: op-connect_op-connect
    external: true
  myservice_internal:
    driver: overlay

secrets:
  op_connect_token:
    external: true
```

## Step 3: Create Validation Script (if needed)

```sh
#!/bin/sh
# scripts/validate-myservice-setup.sh
set -e

echo "=== Validating myservice prerequisites ==="

# Check infrastructure
docker info > /dev/null 2>&1 || { echo "ERROR: Docker not running"; exit 1; }
docker service ls | grep -q "op-connect" || { echo "ERROR: op-connect not running"; exit 1; }

# Check networks
docker network inspect proxy_network > /dev/null 2>&1 || { echo "ERROR: proxy_network missing"; exit 1; }
docker network inspect op-connect_op-connect > /dev/null 2>&1 || { echo "ERROR: op-connect network missing"; exit 1; }

# Check secrets
docker secret inspect op_connect_token > /dev/null 2>&1 || { echo "ERROR: op_connect_token missing"; exit 1; }

# Create directories
mkdir -p /mnt/apps01/appdata/myservice/secrets
chown root:root /mnt/apps01/appdata/myservice
chmod 755 /mnt/apps01/appdata/myservice

echo "=== All prerequisites met ==="
```

## Step 4: Deploy via Komodo

1. Push compose file to git repository
2. Open Komodo UI
3. Navigate to Stacks → Add Stack
4. Point to the stack directory
5. Deploy

## Step 5: Verify Auto-Discovery

Within 60 seconds of deployment:

```bash
# Check service is running
docker service ls --filter "label=com.docker.stack.namespace=myservice"

# Verify Caddy picked up the service
docker service logs caddy_caddy 2>&1 | grep "myservice.in.hypyr.space"

# Verify Homepage shows the service
# → Open https://homepage.in.hypyr.space

# Verify AutoKuma created monitor
# → Open https://uptime.in.hypyr.space → look for "autokuma" tag
```

## Common Patterns

### Add Authentik Forward Auth to a Service

```yaml
deploy:
  labels:
    caddy: myservice.in.hypyr.space
    caddy.forward_auth: http://authentik-server:9000
    caddy.forward_auth.uri: /outpost.goauthentik.io/auth/caddy
    caddy.forward_auth.copy_headers: X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid
    caddy.reverse_proxy: "{{upstreams 8080}}"
    caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"
```

### Add Homepage Widget

```yaml
deploy:
  labels:
    homepage.widget.type: "customapi"
    homepage.widget.url: "http://myservice:8080/api/status"
    homepage.widget.mappings.0.field: "status"
    homepage.widget.mappings.0.label: "Status"
```

### Check Label Placement

```bash
# Verify labels are at service level (not container level)
docker service inspect mystack_myservice --format '{{json .Spec.Labels}}' | jq .
```

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| Service not in Homepage | `docker service inspect --format '{{json .Spec.Labels}}'` | Move labels to `deploy.labels` |
| Caddy 502 Bad Gateway | Service on `proxy_network`? | Add `proxy_network` to service networks |
| AutoKuma no monitor | Check `kuma.*` labels exist | Add AutoKuma labels under `deploy.labels` |
| Secrets job shows "Failed" | `docker service logs <stack>_op-secrets` | Check 1Password Connect and network |
| TLS certificate error | Caddy logs for ACME errors | Verify `CLOUDFLARE_API_TOKEN` secret exists |
