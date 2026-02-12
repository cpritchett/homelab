# Media Support Stack

Supporting media services deployed as Docker Swarm stack `application_media_support`.

## Services

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| Bazarr | `lscr.io/linuxserver/bazarr` | 6767 | `bazarr.in.hypyr.space` | Subtitle management for Sonarr/Radarr |
| Tautulli | `lscr.io/linuxserver/tautulli` | 8181 | `tautulli.in.hypyr.space` | Plex monitoring & analytics |
| Maintainerr | `ghcr.io/jorenn92/maintainerr` | 6246 | `maintainerr.in.hypyr.space` | Plex library maintenance rules |

## Dependencies

This stack requires the core media stack (`application_media_core`) to be deployed and configured first:
- Bazarr connects to Sonarr and Radarr APIs
- Tautulli connects to Plex API
- Maintainerr connects to Plex, Sonarr, and Radarr APIs

## Deployment

```bash
# Via Komodo CLI (after core stack is healthy)
PATH="$HOME/bin:$PATH" km --profile barbary execute deploy-stack application_media_support

# Verify
ssh truenas_admin@barbary "sudo docker service ls --filter label=com.docker.stack.namespace=application_media_support"
```

## Post-Deployment Configuration

1. **Bazarr**: Connect to Sonarr and Radarr using their API keys, configure subtitle providers
2. **Tautulli**: Connect to Plex server (use internal hostname or IP)
3. **Maintainerr**: Connect to Plex, Sonarr, Radarr and configure library maintenance rules
