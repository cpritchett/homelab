# Media Torrent Stack

Torrent-related media services for Docker Swarm stack `application_media_torrent`.

**Status: DEFERRED** — VPN sidecar design is not finalized. These compose files are validated and ready for deployment once the VPN decision is made.

## Services

| Service | Image | Port | URL | Purpose |
|---------|-------|------|-----|---------|
| qBittorrent | `lscr.io/linuxserver/qbittorrent` | 8080 | `qbittorrent.in.hypyr.space` | Torrent client (needs VPN) |
| Cross-Seed | `ghcr.io/cross-seed/cross-seed` | 2468 | `cross-seed.in.hypyr.space` | Cross-seeding automation |
| Autobrr | `ghcr.io/autobrr/autobrr` | 7474 | `autobrr.in.hypyr.space` | Release filter automation |
| Recyclarr | `ghcr.io/recyclarr/recyclarr` | N/A | N/A | TRaSH Guides profile sync (daemon) |

## VPN Dependency

qBittorrent traffic **must** route through a VPN for privacy. Before deploying:

1. Finalize VPN sidecar design (e.g., gluetun container)
2. Add VPN service to compose.yaml
3. Route qBittorrent network through VPN container
4. Test kill switch functionality

## Secrets

Managed via 1Password Connect (ADR-0035). The `op-secrets` replicated-job hydrates `torrent.env.template`.

| Variable | 1Password Reference |
|----------|-------------------|
| `AUTOBRR_API_KEY` | `op://homelab/autobrr/api_key` |
| `AUTOBRR_SESSION_SECRET` | `op://homelab/autobrr/session_secret` |
| `RECYCLARR_API_KEY` | `op://homelab/recyclarr/api_key` |

## Validation

```bash
# Syntax check (does NOT deploy)
docker compose -f stacks/application/media/torrent/compose.yaml config
```

## Deployment (when VPN is ready)

```bash
PATH="$HOME/bin:$PATH" km --profile barbary execute deploy-stack application_media_torrent
```
