# Quickstart: Media Stack Migration (K8s to Docker Swarm)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Prerequisites

- TrueNAS with Docker Swarm operational (infrastructure tier deployed)
- Komodo, Caddy, 1Password Connect running
- Authentik SSO deployed and accessible
- SSH access to TrueNAS host (`ssh truenas_admin@barbary`)
- 1Password items created for media services (see data-model.md)
- UniFi controller accessible for DNS record creation

## Step 1: Create ZFS Datasets and Directories

```bash
ssh truenas_admin@barbary

# Create appdata directories for each service
sudo mkdir -p /mnt/apps01/appdata/media/{plex,sonarr,radarr,prowlarr,sabnzbd,bazarr,tautulli,maintainerr}/{config,secrets}

# Set ownership (1701:1702 for media services)
sudo chown -R 1701:1702 /mnt/apps01/appdata/media/

# Verify media data mount exists
ls -la /mnt/data01/data/

# Create media subdirectories if needed
sudo mkdir -p /mnt/data01/data/{downloads/{complete,incomplete},media/{tv,movies,music}}
sudo chown -R 1701:1702 /mnt/data01/data/
```

## Step 2: Create DNS Records

Create CNAME records for each service via UniFi DNS API:

```bash
# For each service: plex, sonarr, radarr, prowlarr, sabnzbd, bazarr, tautulli, maintainerr
UNIFI_API_KEY=$(op read "op://homelab/unifi/UNIFI_API_KEY")

for svc in plex sonarr radarr prowlarr sabnzbd bazarr tautulli maintainerr; do
  curl -sk -X POST "https://192.168.2.1/proxy/network/v2/api/site/default/static-dns/" \
    -H "X-Api-Key: $UNIFI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"record_type\": \"CNAME\", \"key\": \"${svc}.in.hypyr.space\", \"value\": \"barbary.in.hypyr.space\", \"enabled\": true}"
done
```

## Step 3: Create 1Password Items

Ensure these 1Password items exist in the `homelab` vault:

| Item | Fields | Notes |
|------|--------|-------|
| `plex-stack` | `claim_token` | Generate fresh from https://plex.tv/claim right before deploy |
| `sonarr` | `api_key` | Leave empty initially; populate after first boot |
| `radarr` | `api_key` | Leave empty initially; populate after first boot |
| `prowlarr` | `api_key` | Leave empty initially; populate after first boot |
| `sabnzbd` | `api_key` | Leave empty initially; populate after first boot |

## Step 4: Run Validation Script

```bash
# On TrueNAS, from repo root
cd /mnt/apps01/repos/homelab
sudo sh scripts/validate-media-setup.sh

# Expected output:
# === Validating media stack prerequisites ===
# [OK] Docker is running
# [OK] Swarm mode active
# [OK] proxy_network exists
# [OK] op-connect network exists
# [OK] op_connect_token secret exists
# [OK] 1Password Connect is reachable
# [OK] Directory structure verified
# [OK] /dev/dri exists (GPU passthrough)
# === All prerequisites met ===
```

## Step 5: Deploy Core Stack

```bash
# From workstation
PATH="$HOME/bin:$PATH" km --profile barbary execute deploy-stack application_media_core

# Verify services are running
ssh truenas_admin@barbary "sudo docker service ls --filter 'label=com.docker.stack.namespace=application_media_core'"
# Expected: 6 services (op-secrets: 0/1 completed, 5 app services: 1/1)
```

## Step 6: Verify Core Services

Within 60 seconds of deployment:

```bash
# Check each service is accessible
for svc in plex sonarr radarr prowlarr sabnzbd; do
  echo "Checking ${svc}.in.hypyr.space..."
  curl -sk -o /dev/null -w "%{http_code}" "https://${svc}.in.hypyr.space" && echo
done
# Expected: 200 or 302 (redirect to auth) for each

# Verify Homepage shows Media group
# → Open https://home.in.hypyr.space

# Verify AutoKuma created monitors
# → Open https://status.in.hypyr.space → look for "autokuma" tagged monitors
```

## Step 7: Configure Services

After first deployment, each service needs initial configuration:

1. **Plex**: Navigate to `plex.in.hypyr.space`, complete setup wizard, add library pointing to `/data/media/`
2. **Prowlarr**: Add indexers (NZB sites)
3. **Sonarr**: Add Prowlarr as indexer proxy, add SABnzbd as download client, add root folder `/data/media/tv`
4. **Radarr**: Add Prowlarr as indexer proxy, add SABnzbd as download client, add root folder `/data/media/movies`
5. **SABnzbd**: Configure Usenet servers, set download paths to `/data/downloads/`

## Step 8: Deploy Support Stack

After core is verified:

```bash
PATH="$HOME/bin:$PATH" km --profile barbary execute deploy-stack application_media_support

# Verify
ssh truenas_admin@barbary "sudo docker service ls --filter 'label=com.docker.stack.namespace=application_media_support'"
```

Configure support services:
1. **Bazarr**: Connect to Sonarr and Radarr using API keys, configure subtitle providers
2. **Tautulli**: Connect to Plex server
3. **Maintainerr**: Connect to Plex, Sonarr, Radarr

## Common Patterns

### Add a New Media Service

Follow the label template in the compose files. Every service needs:

```yaml
deploy:
  labels:
    # Homepage (REQUIRED)
    homepage.group: "Media"
    homepage.name: "Service Name"
    homepage.icon: "service.png"
    homepage.href: "https://service.in.hypyr.space"
    homepage.description: "What it does"

    # Caddy (REQUIRED for web UI)
    caddy: service.in.hypyr.space
    caddy.reverse_proxy: "{{upstreams PORT}}"
    caddy.tls.dns: "cloudflare {env.CLOUDFLARE_API_TOKEN}"

    # Authentik Forward Auth (REQUIRED unless service has own auth)
    caddy.forward_auth: http://authentik-server:9000
    caddy.forward_auth.uri: /outpost.goauthentik.io/auth/caddy
    caddy.forward_auth.copy_headers: X-Authentik-Username X-Authentik-Groups X-Authentik-Email X-Authentik-Name X-Authentik-Uid

    # AutoKuma (REQUIRED)
    kuma.service.http.name: "Service Name"
    kuma.service.http.url: "https://service.in.hypyr.space/health"
    kuma.service.http.interval: "60"
    kuma.service.http.maxretries: "3"
```

### Verify GPU Passthrough (Plex)

```bash
ssh truenas_admin@barbary

# Check GPU device exists
ls -la /dev/dri/
# Expected: card0, renderD128

# Check Plex container has GPU access
sudo docker exec $(sudo docker ps -q -f name=plex) ls -la /dev/dri/
```

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| Service not in Homepage | `docker service inspect --format '{{json .Spec.Labels}}'` | Move labels to `deploy.labels` |
| Caddy 502 Bad Gateway | Is service on `proxy_network`? | Add `proxy_network` to service networks |
| AutoKuma no monitor | Check `kuma.*` labels exist | Add AutoKuma labels under `deploy.labels` |
| Secrets job failed | `docker service logs <stack>_op-secrets` | Check 1Password Connect and op-connect network |
| Plex no hardware transcoding | Check `/dev/dri` mount in compose | Add `/dev/dri:/dev/dri` volume |
| Service 403 Forbidden | Authentik outpost not configured for domain | Add application/provider in Authentik for the service domain |
| Cross-stack service unreachable | Services on same network? | Ensure both stacks share `proxy_network` |
| API key empty after deploy | Expected for first boot | Configure service, extract API key, update 1Password item |
