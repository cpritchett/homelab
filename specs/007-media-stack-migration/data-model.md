# Data Model: Media Stack Migration (K8s to Docker Swarm)

**Date**: 2026-02-11
**Spec**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)

## Overview

This feature is infrastructure-as-code — there are no traditional database entities. The "data model" consists of three Docker Swarm stacks, their service definitions, network topology, volume mounts, and secret templates. This document defines the structural contracts for these entities as they apply to the media stack.

---

## Entity: Media Stack

A Docker Swarm stack grouping related media services that share an overlay network and lifecycle.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | YES | Stack name following `application_media_{group}` convention |
| `compose_path` | path | YES | Path to compose.yaml under `stacks/application/media/` |
| `services` | list | YES | Service definitions within the stack |
| `networks` | map | YES | Network definitions (internal overlay + external references) |
| `secrets` | map | NO | External secret references (only if stack uses 1Password) |
| `status` | enum | YES | `active` (deploy now) or `deferred` (VPN pending) |

### Instances

| Stack Name | Services | Secret Template | Status |
|------------|----------|----------------|--------|
| `application_media_core` | Plex, Sonarr, Radarr, Prowlarr, SABnzbd | `media.env.template` | Active |
| `application_media_support` | Bazarr, Tautulli, Maintainerr | None | Active |
| `application_media_torrent` | qBittorrent, Cross-Seed, Autobrr, Recyclarr | `torrent.env.template` | Deferred |

### Validation Rules

- Stack name MUST follow `application_media_{group}` convention
- Active stacks MUST be registered in `komodo/resources.toml`
- Deferred stacks MUST NOT be deployed but MUST pass `docker compose config` validation
- Each stack MUST define at least one internal overlay network

---

## Entity: Media Service

A Docker Swarm service running a media application with standard label metadata.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image` | string | YES | Container image (LinuxServer.io preferred) |
| `internal_port` | integer | YES | Application listen port |
| `fqdn` | string | YES | `<service>.in.hypyr.space` |
| `health_endpoint` | string | YES | HTTP path for health checks |
| `homepage_widget` | string | NO | Homepage widget type (e.g., `sonarr`, `plex`) |
| `requires_auth` | boolean | YES | Whether Authentik forward auth is applied |
| `requires_secrets` | boolean | YES | Whether 1Password injection is needed |
| `requires_gpu` | boolean | NO | Whether `/dev/dri` GPU access is needed |
| `requires_media_mount` | boolean | YES | Whether `/mnt/data01/data` is mounted |
| `config_path` | path | YES | Host path for application config data |

### Instances

| Service | Image | Port | FQDN | Auth | Secrets | GPU | Media | Widget |
|---------|-------|------|------|------|---------|-----|-------|--------|
| Plex | `linuxserver/plex` | 32400 | `plex.in.hypyr.space` | No | Yes | Yes | Yes | `plex` |
| Sonarr | `linuxserver/sonarr` | 8989 | `sonarr.in.hypyr.space` | Yes | Yes | No | Yes | `sonarr` |
| Radarr | `linuxserver/radarr` | 7878 | `radarr.in.hypyr.space` | Yes | Yes | No | Yes | `radarr` |
| Prowlarr | `linuxserver/prowlarr` | 9696 | `prowlarr.in.hypyr.space` | Yes | Yes | No | No | `prowlarr` |
| SABnzbd | `linuxserver/sabnzbd` | 8080 | `sabnzbd.in.hypyr.space` | Yes | Yes | No | Yes | `sabnzbd` |
| Bazarr | `linuxserver/bazarr` | 6767 | `bazarr.in.hypyr.space` | Yes | No | No | Yes | `bazarr` |
| Tautulli | `linuxserver/tautulli` | 8181 | `tautulli.in.hypyr.space` | Yes | No | No | No | `tautulli` |
| Maintainerr | `jorenn92/maintainerr` | 6246 | `maintainerr.in.hypyr.space` | Yes | No | No | No | `customapi` |
| qBittorrent | `linuxserver/qbittorrent` | 8080 | `qbittorrent.in.hypyr.space` | Yes | No | No | Yes | `qbittorrent` |
| Cross-Seed | `cross-seed/cross-seed` | 2468 | `cross-seed.in.hypyr.space` | Yes | No | No | Yes | `customapi` |
| Autobrr | `autobrr/autobrr` | 7474 | `autobrr.in.hypyr.space` | Yes | Yes | No | No | `autobrr` |
| Recyclarr | `recyclarr/recyclarr` | N/A | N/A | N/A | Yes | No | No | N/A |

### Validation Rules

- All services MUST have Homepage labels (group: "Media")
- All services with a web UI MUST have Caddy labels
- All services with a web UI MUST have AutoKuma labels
- Services with `requires_auth: true` MUST have Authentik forward auth labels
- Services with `requires_secrets: true` MUST have a corresponding entry in the stack's env template
- Services with `requires_gpu: true` MUST mount `/dev/dri:/dev/dri`
- Services with `requires_media_mount: true` MUST mount `/mnt/data01/data:/data`
- All services MUST set `PUID=1701` and `PGID=1702` environment variables
- Recyclarr has no web UI, no FQDN, and no labels (daemon-mode cron job)

---

## Entity: Media Secret Template

An `op inject` template file mapping 1Password item fields to environment variables.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `template_path` | path | YES | Path to `.env.template` file in stack directory |
| `output_path` | path | YES | `/mnt/apps01/appdata/media/{stack}/secrets/{name}.env` |
| `references` | list | YES | `op://homelab/{item}/{field}` entries |

### Instances

**Core Stack Template** (`media.env.template`):

| Variable | 1Password Reference | Service |
|----------|-------------------|---------|
| `PLEX_CLAIM` | `op://homelab/plex-stack/claim_token` | Plex (first boot only) |
| `SONARR_API_KEY` | `op://homelab/sonarr/api_key` | Sonarr, Homepage |
| `RADARR_API_KEY` | `op://homelab/radarr/api_key` | Radarr, Homepage |
| `PROWLARR_API_KEY` | `op://homelab/prowlarr/api_key` | Prowlarr, Homepage |
| `SABNZBD_API_KEY` | `op://homelab/sabnzbd/api_key` | SABnzbd, Homepage |

**Torrent Stack Template** (`torrent.env.template`, deferred):

| Variable | 1Password Reference | Service |
|----------|-------------------|---------|
| `AUTOBRR_API_KEY` | `op://homelab/autobrr/api_key` | Autobrr |
| `AUTOBRR_SESSION_SECRET` | `op://homelab/autobrr/session_secret` | Autobrr |
| `RECYCLARR_API_KEY` | `op://homelab/recyclarr/api_key` | Recyclarr |

### Validation Rules

- Template files MUST NOT contain resolved secrets (only `op://` references)
- Template files MUST be mounted read-only in the hydration job
- Output files MUST have permissions 644
- All referenced 1Password items MUST exist before deployment

---

## Entity: Komodo Stack Resource

A Komodo resource definition for deploying and managing a media stack.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | YES | Stack name matching Docker Swarm stack name |
| `swarm` | string | YES | `homelab-swarm` (Swarm deployment mode) |
| `linked_repo` | string | YES | `homelab-repo` |
| `run_directory` | path | YES | Path to stack directory relative to repo root |
| `auto_pull` | boolean | YES | Whether Komodo pulls images before deploy |
| `webhook_enabled` | boolean | YES | Whether GitHub webhooks trigger redeploy |
| `send_alerts` | boolean | YES | Whether deployment failures send alerts |
| `pre_deploy` | object | NO | Validation script to run before deployment |

### Instances

| Stack | Run Directory | Pre-Deploy Script |
|-------|--------------|-------------------|
| `application_media_core` | `stacks/application/media/core` | `scripts/validate-media-setup.sh` |
| `application_media_support` | `stacks/application/media/support` | `scripts/validate-media-setup.sh` |
| `application_media_torrent` | `stacks/application/media/torrent` | N/A (deferred) |

---

## Entity: DNS Record

Internal DNS records for media service access.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `hostname` | string | YES | Service subdomain (e.g., `sonarr`) |
| `type` | enum | YES | `CNAME` |
| `target` | string | YES | `barbary.in.hypyr.space` |
| `zone` | string | YES | `in.hypyr.space` |

### Instances

One CNAME record per web-accessible service:
`plex`, `sonarr`, `radarr`, `prowlarr`, `sabnzbd`, `bazarr`, `tautulli`, `maintainerr`, `qbittorrent` (deferred), `cross-seed` (deferred), `autobrr` (deferred)

All CNAMEs point to `barbary.in.hypyr.space`. Created via UniFi DNS API.

---

## Relationships

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Secret       │────▶│ Media        │────▶│ Label        │
│ Template     │     │ Service      │     │ Schema       │
│              │     │              │     │ (ADR-0034)   │
└──────────────┘     └──────┬───────┘     └──────────────┘
                            │
                     ┌──────┴───────┐
                     │              │
              ┌──────▼──────┐ ┌────▼─────────┐
              │ Media       │ │ Komodo       │
              │ Stack       │ │ Resource     │
              └──────┬──────┘ └──────────────┘
                     │
              ┌──────▼──────┐
              │ DNS         │
              │ Record      │
              └─────────────┘
```

- Secret Templates **produce** environment files consumed by Media Services
- Media Services **declare** Label Schema entries consumed by Caddy/Homepage/AutoKuma
- Media Services **belong to** Media Stacks for lifecycle management
- Media Stacks **are managed by** Komodo Resources for deployment
- DNS Records **enable access** to Media Services via Caddy reverse proxy
