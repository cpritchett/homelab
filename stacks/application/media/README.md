# Media Stack

Media applications deployed as Docker Swarm stacks on TrueNAS, managed by Komodo.

## Stacks

| Stack | Path | Services | Status |
|-------|------|----------|--------|
| [Core](core/README.md) | `stacks/application/media/core/` | Plex, Sonarr, Radarr, Prowlarr, SABnzbd | Active |
| [Support](support/README.md) | `stacks/application/media/support/` | Bazarr, Tautulli, Maintainerr | Active |
| [Torrent](torrent/README.md) | `stacks/application/media/torrent/` | qBittorrent, Cross-Seed, Autobrr, Recyclarr | Deferred (VPN) |

## Deployment Order

1. **Core** — must be deployed first (other stacks depend on these services)
2. **Support** — deploy after core services are healthy and configured
3. **Torrent** — deferred until VPN sidecar design is finalized

## Shared Configuration

- **User/Group**: All services run as UID 1701 / GID 1702
- **Media Data**: `/mnt/data01/data` (downloads, TV, movies, music)
- **App Config**: `/mnt/apps01/appdata/media/<service>/config`
- **Secrets**: 1Password Connect via `op-secrets` replicated-job (ADR-0035)
- **Ingress**: Caddy reverse proxy with TLS at `<service>.in.hypyr.space`
- **Auth**: Authentik forward auth (except Plex, which uses its own auth)
- **Monitoring**: AutoKuma labels for Uptime Kuma monitors
- **Dashboard**: Homepage labels in "Media" group

## Validation

```bash
sudo sh scripts/validate-media-setup.sh
```

## References

- [Spec](../../specs/007-media-stack-migration/spec.md)
- [ADR-0033](../../docs/adr/ADR-0033-truenas-swarm-migration.md) (Phase 3)
- [ADR-0034](../../docs/adr/ADR-0034-label-driven-infrastructure.md) (Label governance)
- [ADR-0035](../../docs/adr/ADR-0035-secret-hydration.md) (Secret hydration)
