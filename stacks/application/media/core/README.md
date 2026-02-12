# Media Core Stack

Core media pipeline services deployed as Docker Swarm stack `application_media_core`.

## Services

| Service | Image | Port | URL | Auth |
|---------|-------|------|-----|------|
| Plex | `lscr.io/linuxserver/plex` | 32400 | `plex.in.hypyr.space` | Plex account (own auth) |
| Sonarr | `lscr.io/linuxserver/sonarr` | 8989 | `sonarr.in.hypyr.space` | Authentik SSO |
| Radarr | `lscr.io/linuxserver/radarr` | 7878 | `radarr.in.hypyr.space` | Authentik SSO |
| Prowlarr | `lscr.io/linuxserver/prowlarr` | 9696 | `prowlarr.in.hypyr.space` | Authentik SSO |
| SABnzbd | `lscr.io/linuxserver/sabnzbd` | 8080 | `sabnzbd.in.hypyr.space` | Authentik SSO |

## Secrets

Managed via 1Password Connect (ADR-0035). The `op-secrets` replicated-job hydrates `media.env.template` into `/mnt/apps01/appdata/media/core/secrets/media.env`.

| Variable | 1Password Reference |
|----------|-------------------|
| `PLEX_CLAIM` | `op://homelab/plex-stack/claim_token` |
| `SONARR_API_KEY` | `op://homelab/sonarr/api_key` |
| `RADARR_API_KEY` | `op://homelab/radarr/api_key` |
| `PROWLARR_API_KEY` | `op://homelab/prowlarr/api_key` |
| `SABNZBD_API_KEY` | `op://homelab/sabnzbd/api_key` |

## Deployment

```bash
# Via Komodo CLI
PATH="$HOME/bin:$PATH" km --profile barbary execute deploy-stack application_media_core

# Verify
ssh truenas_admin@barbary "sudo docker service ls --filter label=com.docker.stack.namespace=application_media_core"
```

## Post-Deployment Configuration

1. **Plex**: Complete setup wizard at `plex.in.hypyr.space`, add library pointing to `/data/media/`
2. **Prowlarr**: Add indexers (NZB sites)
3. **Sonarr**: Add Prowlarr as indexer proxy, add SABnzbd as download client, set root folder `/data/media/tv`
4. **Radarr**: Add Prowlarr as indexer proxy, add SABnzbd as download client, set root folder `/data/media/movies`
5. **SABnzbd**: Configure Usenet servers, set download paths to `/data/downloads/`
