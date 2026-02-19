# Storage Architecture

## TrueNAS Mount Layout

TrueNAS provides two primary ZFS pools with distinct purposes:

```
/mnt/apps01/                          # Application configs, secrets, repos
├── appdata/
│   ├── proxy/
│   │   ├── caddy-data/               # TLS certificates
│   │   ├── caddy-config/             # Caddyfile
│   │   └── caddy-secrets/            # Injected env
│   ├── komodo/
│   │   ├── mongodb/                  # Komodo state DB
│   │   ├── sync/                     # ResourceSync data
│   │   ├── backups/                  # Stack backups
│   │   ├── periphery/               # Periphery config
│   │   └── secrets/                  # Injected env
│   ├── authentik/
│   │   ├── media/                    # Custom assets
│   │   ├── custom-templates/         # OIDC/SAML templates
│   │   ├── blueprints/              # Auto-generated
│   │   ├── postgres/                 # Authentik DB
│   │   ├── redis/                    # Session store
│   │   └── secrets/                  # Injected env
│   ├── homepage/
│   │   ├── config/                   # Dashboard YAML
│   │   ├── icons/                    # Custom icons
│   │   ├── images/                   # Custom images
│   │   └── secrets/                  # Injected env
│   ├── monitoring/
│   │   ├── prometheus/               # TSDB (15-day retention)
│   │   ├── loki/                     # Log chunks
│   │   ├── grafana/                  # Dashboards, config
│   │   ├── alloy-data/              # Alloy WAL
│   │   └── secrets/                  # Grafana env
│   ├── postgres/
│   │   ├── data/                     # Shared app databases
│   │   ├── backups/                  # Daily pg_dumpall
│   │   └── secrets/                  # Injected env
│   ├── uptime-kuma/                  # SQLite DB
│   ├── forgejo/
│   │   ├── gitea/                    # Repos, LFS, config (app.ini)
│   │   ├── postgres/                 # Forgejo-dedicated DB
│   │   └── secrets/                  # Injected env
│   ├── woodpecker/
│   │   ├── woodpecker.db             # SQLite DB
│   │   └── secrets/                  # Injected env
│   └── media/
│       ├── plex/config/
│       ├── jellyfin/config/
│       ├── sonarr/config/
│       ├── radarr/config/
│       ├── prowlarr/config/
│       ├── sabnzbd/config/
│       ├── bazarr/config/
│       ├── tautulli/config/
│       ├── maintainerr/config/
│       ├── seerr/config/
│       ├── wizarr/database/
│       ├── recyclarr/config/
│       ├── tracearr/config/
│       ├── tracearr/image-cache/
│       ├── tracearr/timescaledb/     # TimescaleDB data
│       ├── tracearr/redis/           # Redis AOF
│       ├── kometa/config/
│       ├── titlecardmaker/config/
│       ├── posterizarr/config/ + assets/
│       ├── core/secrets/             # Injected media.env
│       ├── support/secrets/          # Injected support.env
│       └── torrent/secrets/          # Injected torrent.env
├── repos/
│   └── homelab/                      # Git repo (main branch)
└── secrets/                          # Bootstrap credentials (not in git)

/mnt/data01/                          # Bulk/static assets (spinning rust)
└── data/                             # Media library
    ├── media/                        # Movies, TV, Music
    └── usenet/                       # Download staging
```

**Design rationale:** `/mnt/apps01` holds all application data — config, secrets, and databases — on fast SSD storage. `/mnt/data01` is reserved for bulk/static assets that tolerate spinning rust (media library, download staging).

## Per-Service Storage Map

| Service | Mount Path | Stores | Pinned to barbary |
|---------|-----------|--------|-------------------|
| Plex | `/mnt/apps01/appdata/media/plex/config` | Metadata DB, preferences | Yes (iGPU) |
| Jellyfin | `/mnt/apps01/appdata/media/jellyfin/config` | Metadata DB, preferences | Yes (iGPU) |
| Sonarr | `/mnt/apps01/appdata/media/sonarr/config` | Config files (DB in PostgreSQL) | No |
| Radarr | `/mnt/apps01/appdata/media/radarr/config` | Config files (DB in PostgreSQL) | No |
| Prowlarr | `/mnt/apps01/appdata/media/prowlarr/config` | Config files (DB in PostgreSQL) | No |
| SABnzbd | `/mnt/apps01/appdata/media/sabnzbd/config` | SQLite DB, config | Yes |
| Bazarr | `/mnt/apps01/appdata/media/bazarr/config` | SQLite DB, config | Yes |
| Tautulli | `/mnt/apps01/appdata/media/tautulli/config` | SQLite DB | Yes |
| Maintainerr | `/mnt/apps01/appdata/media/maintainerr/config` | SQLite DB | Yes |
| Seerr | `/mnt/apps01/appdata/media/seerr/config` | Config files (DB in PostgreSQL) | No |
| Wizarr | `/mnt/apps01/appdata/media/wizarr/database` | SQLite DB | Yes |
| Tracearr | `/mnt/apps01/appdata/media/tracearr/config` | Config files (DB in TimescaleDB) | No |
| Tracearr TimescaleDB | `/mnt/apps01/appdata/media/tracearr/timescaledb` | Time-series analytics DB | Yes |
| Tracearr Redis | `/mnt/apps01/appdata/media/tracearr/redis` | Session cache (AOF) | No |
| Prometheus | `/mnt/apps01/appdata/monitoring/prometheus` | TSDB (15-day retention) | Yes |
| Loki | `/mnt/apps01/appdata/monitoring/loki` | Log chunks | Yes |
| Grafana | `/mnt/apps01/appdata/monitoring/grafana` | Dashboards, plugins | No (PostgreSQL backend) |
| PostgreSQL | `/mnt/apps01/appdata/postgres/data` | All shared app databases | Yes |
| Uptime Kuma | `/mnt/apps01/appdata/uptime-kuma` | SQLite DB | Yes |
| MongoDB | `/mnt/apps01/appdata/komodo/mongodb` | Komodo state | Yes |
| Forgejo | `/mnt/apps01/appdata/forgejo` | Git repos, LFS, config (DB in dedicated PostgreSQL) | Yes |
| Woodpecker | `/mnt/apps01/appdata/woodpecker` | SQLite DB | Yes |

## Backup Strategy

### PostgreSQL (shared)

A `pg-backup` sidecar runs daily `pg_dumpall` with 7-day retention:

- **Destination:** `/mnt/apps01/appdata/postgres/backups/`
- **Schedule:** Nightly
- **Databases:** grafana, sonarr-main, sonarr-log, radarr-main, radarr-log, prowlarr-main, prowlarr-log, seerr (shared PostgreSQL); forgejo (dedicated PostgreSQL)

> **Note:** Tracearr's TimescaleDB is a dedicated instance (not the shared PostgreSQL) and is NOT covered by the `pg-backup` sidecar. Back up separately if needed.

### Application Config (future)

Restic-based backup of `/mnt/apps01/appdata/` is planned but not yet implemented.

## NFS Mounts

Worker nodes (lorcha, dhow) and Proxmox VMs (ching, angre) access TrueNAS storage via NFS. The Ansible `nfs` role configures `/etc/fstab` entries:

- `/mnt/apps01/appdata` — application config (read/write)
- `/mnt/data01/data` — media files (read/write)

Services running on non-barbary nodes use these NFS mounts transparently. Services that require local filesystem semantics (SQLite, TSDB) are pinned to barbary where storage is native ZFS.

## UID/GID Conventions

| User/Group | UID | GID | Services |
|-----------|-----|-----|----------|
| media | 1701 | 1702 | Plex, Jellyfin, Sonarr, Radarr, Prowlarr, SABnzbd, Bazarr, Recyclarr, Kometa, TitleCardMaker, Posterizarr |
| node | 1000 | 1000 | Seerr, Forgejo |
| caddy | 1701 | 1702 | Caddy (shares media group for socket access) |
| opuser | 999 | 999 | 1Password Connect init jobs (secrets dirs must be 999:999 mode 750) |
| cloudflared | 65532 | 65532 | cloudflared (nonroot default) |
| postgres | 70 | 70 | PostgreSQL (alpine image) |
| tracearr | 1001 | 1001 | Tracearr |
| mongodb | 568 | 568 | Komodo MongoDB |

All media services run as `PUID=1701 PGID=1702` to ensure consistent file ownership across the shared `/mnt/data01/data` mount.

## Related Documentation

- [Overview](overview.md) — node topology, tier model
- [Secrets](secrets.md) — secret injection into storage paths
- [Deployment Flow](deployment-flow.md) — how stacks reference storage
