# Research: Media Stack Migration (K8s to Docker Swarm)

**Date**: 2026-02-11
**Spec**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)

## Overview

This research addresses the technical decisions for migrating 12 media applications from Kubernetes HelmReleases to Docker Swarm stacks on TrueNAS. This is a greenfield deployment — services start fresh with no data migration from Kubernetes. Research focuses on four areas: stack topology and networking, service configuration patterns, secret management, and GPU passthrough for Plex hardware transcoding.

---

## R1: Stack Topology and Networking

### Decision: Three Independent Stacks with Shared Overlay Network

**Rationale**: Services are grouped by operational lifecycle — core pipeline services (Plex, Sonarr, Radarr, Prowlarr, SABnzbd) must all be running for media acquisition to work, supporting services (Bazarr, Tautulli, Maintainerr) enhance but aren't critical, and torrent services (qBittorrent, Cross-Seed, Autobrr, Recyclarr) are deferred pending VPN design. Independent stacks allow deploying and updating each group without affecting the others.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Single monolithic stack (all 12 services) | Update to one service restarts entire stack; torrent deferral complicates deployment |
| Per-service stacks (12 stacks) | Excessive Komodo resource entries; network complexity; operational overhead |
| Two stacks (active + deferred) | Support services have different update cadence than core pipeline |

### Key Findings

**Stack Definitions**:

| Stack | Compose Path | Services | Status |
|-------|-------------|----------|--------|
| `application_media_core` | `stacks/application/media/core/compose.yaml` | Plex, Sonarr, Radarr, Prowlarr, SABnzbd, op-secrets | Deploy immediately |
| `application_media_support` | `stacks/application/media/support/compose.yaml` | Bazarr, Tautulli, Maintainerr | Deploy after core verified |
| `application_media_torrent` | `stacks/application/media/torrent/compose.yaml` | qBittorrent, Cross-Seed, Autobrr, Recyclarr, op-secrets | Deferred (VPN dependency) |

**Network Architecture**:

| Network | Type | Purpose | Used By |
|---------|------|---------|---------|
| `proxy_network` | external overlay | Caddy ingress + service discovery | All web-accessible services |
| `media` | stack overlay | Inter-service communication | All services in the same stack |
| `op-connect_op-connect` | external overlay | 1Password Connect access | op-secrets hydration jobs |

**Cross-Stack Communication**: Sonarr/Radarr need to reach Prowlarr (indexer) and SABnzbd (download client). Since all five are in the same `application_media_core` stack, they communicate via the stack-internal `media` overlay network using Swarm DNS names (e.g., `prowlarr`, `sabnzbd`).

Support services (Bazarr, Tautulli, Maintainerr) need to reach core services (Sonarr, Radarr, Plex). Since these are in different stacks, they communicate via `proxy_network` using the service's Caddy FQDN or by defining the core stack's overlay network as external and attaching to it.

**Decision**: Use `proxy_network` for cross-stack communication. All services are already on this network for Caddy ingress. Services can reach each other via their Swarm service aliases on `proxy_network`. This avoids creating additional external networks.

---

## R2: Service Configuration and Label Patterns

### Decision: Standard Label-Driven Pattern (ADR-0034) with Media-Specific Widgets

**Rationale**: All 12 services follow the same label pattern established in spec 002. Each service gets Homepage labels (group: "Media"), Caddy labels (TLS + forward auth), and AutoKuma labels (HTTP health checks). Several services have native Homepage widgets available.

### Key Findings

**Service Port Mapping**:

| Service | Image | Internal Port | Health Endpoint | Homepage Widget |
|---------|-------|--------------|-----------------|-----------------|
| Plex | `linuxserver/plex` | 32400 | `/web/index.html` | `plex` |
| Sonarr | `linuxserver/sonarr` | 8989 | `/ping` | `sonarr` |
| Radarr | `linuxserver/radarr` | 7878 | `/ping` | `radarr` |
| Prowlarr | `linuxserver/prowlarr` | 9696 | `/ping` | `prowlarr` |
| SABnzbd | `linuxserver/sabnzbd` | 8080 | `/api?mode=version` | `sabnzbd` |
| Bazarr | `linuxserver/bazarr` | 6767 | `/ping` | `bazarr` |
| Tautulli | `linuxserver/tautulli` | 8181 | `/status` | `tautulli` |
| Maintainerr | `ghcr.io/jorenn92/maintainerr` | 6246 | `/` | `customapi` |
| qBittorrent | `linuxserver/qbittorrent` | 8080 | `/api/v2/app/version` | `qbittorrent` |
| Cross-Seed | `ghcr.io/cross-seed/cross-seed` | 2468 | `/api/status` | `customapi` |
| Autobrr | `ghcr.io/autobrr/autobrr` | 7474 | `/api/healthz/liveness` | `autobrr` |
| Recyclarr | `ghcr.io/recyclarr/recyclarr` | N/A (cron) | N/A | N/A |

**LinuxServer.io Pattern**: Most services use LinuxServer.io images which provide a consistent interface:
- Environment: `PUID=1701`, `PGID=1702`, `TZ=America/New_York`
- Config volume: `/config` maps to host `/mnt/apps01/appdata/media/<service>/config`
- These images handle user mapping internally via `PUID`/`PGID`

**Authentik Forward Auth**: All services use forward auth EXCEPT:
- Plex: Uses its own Plex account authentication system
- Recyclarr: No web UI (cron job)

**Homepage Widget API Keys**: Several Homepage widgets (Sonarr, Radarr, Prowlarr, SABnzbd, Tautulli) require API keys. These keys are generated after first deployment during service configuration. The Homepage widget `key` field can be set via `homepage.widget.key` deploy label using a `{{HOMEPAGE_VAR_*}}` environment variable reference, or the widget can be added post-deployment.

**Decision**: Deploy services initially WITHOUT Homepage widget API key labels. After services are configured and API keys are generated, update the compose files with the widget key labels and redeploy. This avoids a circular dependency (can't get API keys before first deployment).

---

## R3: Secret Management for Media Services

### Decision: Selective Secret Hydration (Core + Torrent Only)

**Rationale**: Not all media services require secrets from 1Password. LinuxServer.io images configure themselves via environment variables (PUID, PGID, TZ) that are not sensitive. Only services with API keys or credentials that must not be in Git need 1Password injection.

### Key Findings

**Services Requiring 1Password Secrets**:

| Service | 1Password Item | Fields | Reason |
|---------|---------------|--------|--------|
| Plex | `plex-stack` (new) | `claim_token` | Initial Plex server claim |
| Sonarr | `sonarr` (existing) | `api_key` | API key for inter-service auth |
| Radarr | `radarr` (existing) | `api_key` | API key for inter-service auth |
| Prowlarr | `prowlarr` (existing) | `api_key` | API key for inter-service auth |
| SABnzbd | `sabnzbd` (existing) | `api_key` | API key for inter-service auth |
| Autobrr | `autobrr` (existing, deferred) | `api_key`, `session_secret` | Web auth |
| Recyclarr | `recyclarr` (existing, deferred) | `api_key` | Sonarr/Radarr sync auth |

**Services NOT Requiring 1Password Secrets**:
- Bazarr: Configured via UI, stores API keys locally in `/config`
- Tautulli: Configured via UI, stores API keys locally in `/config`
- Maintainerr: Configured via UI, stores tokens locally
- qBittorrent: Generates admin password on first run
- Cross-Seed: Configured via `/config/config.js`

**Secret Hydration Pattern**: The core stack uses a single `op-secrets` replicated-job that hydrates all core service secrets into one env file (`media-core.env`). This follows ADR-0035. The torrent stack (when deployed) gets its own `op-secrets` job for torrent-specific secrets.

**Plex Claim Token**: Plex requires a one-time claim token from `https://plex.tv/claim` for initial server registration. This token expires after 4 minutes. It should be generated immediately before first deployment and injected via 1Password. After initial claim, the token is no longer needed.

**Homepage Widget API Keys**: After services generate their API keys on first run, these keys should be stored in the respective 1Password items. The Homepage env template can then reference them for widget configuration.

**Template File** (`media.env.template`):
```
SONARR_API_KEY=op://homelab/sonarr/api_key
RADARR_API_KEY=op://homelab/radarr/api_key
PROWLARR_API_KEY=op://homelab/prowlarr/api_key
SABNZBD_API_KEY=op://homelab/sabnzbd/api_key
PLEX_CLAIM=op://homelab/plex-stack/claim_token
```

**Decision**: API keys for Sonarr, Radarr, Prowlarr, and SABnzbd will be populated in 1Password AFTER first deployment. The initial deployment will use empty/placeholder values in 1Password, and services will generate their own keys. Post-deployment, the generated keys are stored back to 1Password for Homepage widget integration.

---

## R4: Plex GPU Passthrough for Hardware Transcoding

### Decision: Docker Swarm `generic_resources` with `/dev/dri` Device Mount

**Rationale**: Plex requires access to the Intel GPU (QuickSync) for hardware transcoding. Docker Swarm does not support `--device` flag directly, but does support generic resources and bind-mounting device files.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Docker Compose mode (not Swarm) | Loses Swarm orchestration, label discovery, overlay networking |
| Software transcoding only | Significantly higher CPU usage; poor 4K transcoding performance |
| NVIDIA GPU | TrueNAS has Intel iGPU (QuickSync), not NVIDIA |
| Privileged mode | Security risk; violates principle of least privilege |

### Key Findings

**GPU Device Access in Swarm**:
Docker Swarm does not support the `devices:` directive in compose files. Two approaches exist:

1. **Generic Resources** (recommended): Configure the Docker daemon to advertise GPU resources, then request them in compose:
   ```yaml
   deploy:
     resources:
       reservations:
         generic_resources:
           - discrete_resource_spec:
               kind: 'gpu'
               value: 1
   ```
   This requires adding to `/etc/docker/daemon.json`:
   ```json
   {
     "node-generic-resources": ["gpu=1"]
   }
   ```

2. **Bind-mount `/dev/dri`** (simpler): Mount the device directory as a volume:
   ```yaml
   volumes:
     - /dev/dri:/dev/dri
   ```
   This works because TrueNAS is single-node — the GPU is always on the local host.

**Decision**: Use bind-mount approach (`/dev/dri:/dev/dri`) for simplicity. The single-node TrueNAS deployment doesn't require Swarm scheduling awareness of GPU resources. The LinuxServer Plex image detects `/dev/dri` automatically and enables hardware transcoding.

**Verification**: After deployment, verify transcoding works:
1. Play a media file in Plex that requires transcoding
2. Check Plex dashboard for "(hw)" indicator in transcoding session
3. Verify via `ls -la /dev/dri` on TrueNAS that `renderD128` exists

**User/Group Requirements**: The container user (1701) must be in the `video` group on the host to access `/dev/dri/renderD128`. LinuxServer images handle this via the `PUID`/`PGID` environment variables. On TrueNAS, the video group GID may need to be mapped.

---

## R5: Storage Layout and Volume Mounts

### Decision: Consistent Host Path Pattern Across All Services

**Rationale**: All media services share the same media library (downloads, TV, movies) and each stores application config separately. Using consistent, predictable paths simplifies validation scripts and documentation.

### Key Findings

**Storage Tiers**:

| Tier | ZFS Pool | Mount Point | Purpose | Services |
|------|----------|-------------|---------|----------|
| App Config | `apps01` | `/mnt/apps01/appdata/media/<service>/config` | Service configuration, databases | All services |
| App Secrets | `apps01` | `/mnt/apps01/appdata/media/<service>/secrets` | Hydrated env files | Core, Torrent |
| Media Data | `data01` | `/mnt/data01/data` | Downloads, TV, Movies, Music | All media services |

**Media Directory Structure** (under `/mnt/data01/data`):

```
/mnt/data01/data/
├── downloads/
│   ├── complete/
│   └── incomplete/
├── media/
│   ├── tv/
│   ├── movies/
│   └── music/
└── torrents/
    ├── complete/
    └── incomplete/
```

**Volume Mounts Per Service**:

| Service | Config Mount | Media Mount | Secrets Mount | Extra Mounts |
|---------|-------------|-------------|---------------|--------------|
| Plex | `/mnt/apps01/.../plex/config:/config` | `/mnt/data01/data:/data` | `/mnt/apps01/.../plex/secrets:/secrets:ro` | `/dev/dri:/dev/dri` |
| Sonarr | `/mnt/apps01/.../sonarr/config:/config` | `/mnt/data01/data:/data` | `/mnt/apps01/.../sonarr/secrets:/secrets:ro` | — |
| Radarr | `/mnt/apps01/.../radarr/config:/config` | `/mnt/data01/data:/data` | `/mnt/apps01/.../radarr/secrets:/secrets:ro` | — |
| Prowlarr | `/mnt/apps01/.../prowlarr/config:/config` | — | `/mnt/apps01/.../prowlarr/secrets:/secrets:ro` | — |
| SABnzbd | `/mnt/apps01/.../sabnzbd/config:/config` | `/mnt/data01/data:/data` | `/mnt/apps01/.../sabnzbd/secrets:/secrets:ro` | — |
| Bazarr | `/mnt/apps01/.../bazarr/config:/config` | `/mnt/data01/data:/data` | — | — |
| Tautulli | `/mnt/apps01/.../tautulli/config:/config` | — | — | — |
| Maintainerr | `/mnt/apps01/.../maintainerr/config:/config` | — | — | — |

Note: Prowlarr doesn't need media data access (it only manages indexers). Tautulli and Maintainerr don't need media data access (they interact via API only).

**Ownership**: All directories under `/mnt/apps01/appdata/media/` and media data under `/mnt/data01/data` must be owned by `1701:1702`. The validation script ensures this.

---

## R6: Recyclarr as a Swarm Scheduled Service

### Decision: Swarm Replicated Job with Restart Delay (Cron Emulation)

**Rationale**: Recyclarr syncs TRaSH Guides quality profiles to Sonarr/Radarr on a schedule. It's not a long-running service — it runs, syncs, and exits. Docker Swarm doesn't have native cron support, but the restart policy can emulate periodic execution.

**Alternatives Considered**:

| Alternative | Rejected Because |
|-------------|-----------------|
| Host crontab | Not managed by Swarm; no label discovery; manual maintenance |
| `swarm-cronjob` | Additional infrastructure dependency; not in existing toolchain |
| Long-running Recyclarr daemon | Recyclarr v7+ supports daemon mode with built-in scheduler; viable |

**Decision Update**: Recyclarr v7+ includes a built-in scheduler (`recyclarr sync --run-at-start`). Use the daemon mode as a normal `replicated` service, letting Recyclarr handle its own scheduling. This is simpler than emulating cron via Swarm restart policies.

---

## R7: Technology Best Practices Summary

### Docker Swarm Media Stack Patterns

| Pattern | Best Practice | Source |
|---------|--------------|--------|
| Image source | LinuxServer.io images where available (consistent PUID/PGID/TZ interface) | Community standard |
| User mapping | `PUID=1701`, `PGID=1702` environment variables | FR-007 |
| Config storage | `/mnt/apps01/appdata/media/<service>/config:/config` | FR-009 |
| Media storage | `/mnt/data01/data:/data` (read-write for downloaders, read-only for Plex) | FR-008 |
| GPU passthrough | `/dev/dri:/dev/dri` bind mount for Intel QuickSync | FR-010 |
| Secret hydration | Single `op-secrets` job per stack (ADR-0035) | FR-006 |
| Label placement | All labels under `deploy.labels` (ADR-0034) | Spec 002 |
| Forward auth | Authentik labels on all services except Plex | FR-003 |
| Health monitoring | AutoKuma HTTP checks against service health endpoints | FR-005 |

### Service Interaction Matrix

```
Prowlarr ──indexers──▶ Sonarr ──downloads──▶ SABnzbd
                       Radarr ──downloads──▶ SABnzbd
                                               │
                                          ┌────┘
                                          ▼
Plex ◀──library scan── /mnt/data01/data/media/
  │
  ├──▶ Tautulli (API monitoring)
  └──▶ Maintainerr (library rules)

Sonarr ◀──▶ Bazarr (subtitle management)
Radarr ◀──▶ Bazarr (subtitle management)

Recyclarr ──profile sync──▶ Sonarr
Recyclarr ──profile sync──▶ Radarr
```

---

## Open Questions (None)

All technical decisions are resolved through codebase analysis and existing patterns from spec 002. The media stack follows established infrastructure patterns with minimal deviation (GPU passthrough being the only media-specific addition).
