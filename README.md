<div align="center">

# hypyr homelab

### Docker Swarm on TrueNAS | Komodo | Caddy | 1Password Connect

[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?style=flat-square&logo=renovatebot)](https://github.com/renovatebot/renovate)

![Plex](https://status.hypyr.space/api/badge/143/status?label=Plex&style=flat-square)
![Jellyfin](https://status.hypyr.space/api/badge/163/status?label=Jellyfin&style=flat-square)
![Caddy](https://status.hypyr.space/api/badge/165/status?label=Caddy&style=flat-square)
![Authentik](https://status.hypyr.space/api/badge/155/status?label=Authentik&style=flat-square)
![Grafana](https://status.hypyr.space/api/badge/146/status?label=Grafana&style=flat-square)
![Uptime](https://status.hypyr.space/api/badge/143/uptime/720?label=Uptime&style=flat-square)

*Push to main. Komodo pulls. Services update. No clicking around in UIs.*

</div>

---

## Overview

This repo is the single source of truth for my homelab — a five-node Docker Swarm cluster running on a mix of TrueNAS, Proxmox VMs, and bare metal. Everything is declared as code and deployed via GitOps through [Komodo ResourceSync](https://github.com/moghtech/komodo).

## Hardware

| Node | Role | Hardware | CPU | RAM | Storage | Notes |
|------|------|----------|-----|-----|---------|-------|
| **barbary** | Manager (leader) | 45Drives HL15 | Intel (QuickSync) | 128GB | ~100TB HDD + 4TB NVMe (mirrored) | TrueNAS Scale, iGPU transcoding |
| **ching** | Manager | IBM P520 (Proxmox) | 16 vCPU | 128GB | SATA SSD + NVMe | Swarm quorum + workloads |
| **angre** | Manager | Custom ITX (Proxmox) | 8 vCPU | 64GB | SATA SSD + NVMe | Swarm quorum + workloads |
| **lorcha** | Worker | Beelink EQ12 | Intel N100 | 32GB | SATA SSD + NVMe | Application workloads |
| **dhow** | Worker | Beelink EQ12 | Intel N100 | 32GB | SATA SSD + NVMe | Application workloads |

Stateful services (SQLite, TSDB, iGPU transcoding) are pinned to barbary. Everything else floats across nodes via NFS.

## Tech Stack

| | Component | Tool |
|---|-----------|------|
| :whale: | Orchestration | Docker Swarm |
| :rocket: | Deployment | [Komodo](https://github.com/moghtech/komodo) ResourceSync |
| :globe_with_meridians: | Reverse Proxy | [Caddy](https://caddyserver.com/) + caddy-docker-proxy |
| :closed_lock_with_key: | Secrets | [1Password Connect](https://developer.1password.com/docs/connect/) + `op inject` |
| :shield: | SSO | [Authentik](https://goauthentik.io/) |
| :cloud: | Tunnel | [cloudflared](https://github.com/cloudflare/cloudflared) → Cloudflare |
| :satellite: | DNS | UniFi (internal) + Cloudflare (external) |
| :bar_chart: | Monitoring | Prometheus · Grafana · Loki · Alloy |
| :green_heart: | Uptime | Uptime Kuma + AutoKuma |
| :house: | Dashboard | [Homepage](https://gethomepage.dev/) |
| :hammer_and_wrench: | CI/CD | Forgejo + Woodpecker |
| :robot: | Automation | [n8n](https://n8n.io/) |
| :floppy_disk: | Database | PostgreSQL (shared + dedicated instances) |
| :package: | Backups | [Restic](https://restic.net/) → S3 |
| :arrows_counterclockwise: | Deps | [Renovate](https://github.com/renovatebot/renovate) |
| :wrench: | Provisioning | Ansible + OpenTofu (Proxmox) |
| :electric_plug: | PXE | dnsmasq + Matchbox |

## Services

### Media

The full *arr stack and then some.

| Service | What it does |
|---------|-------------|
| **Plex** | Primary media server (iGPU transcoding) |
| **Jellyfin** | Secondary media server |
| **Sonarr** | TV shows |
| **Radarr** | Movies |
| **Prowlarr** | Indexer management |
| **SABnzbd** | Usenet downloads |
| **qBittorrent** | Torrents |
| **Bazarr** | Subtitles |
| **Recyclarr** | TRaSH guide sync |
| **Tautulli** | Plex analytics |
| **Maintainerr** | Media lifecycle rules |
| **Seerr** | Media requests |
| **Wizarr** | User invitations |
| **Doplarr** | Discord request bot |
| **Autobrr** | Torrent automation |
| **Cross-seed** | Cross-seeding |
| **Decluttarr** | Queue cleanup |
| **Tracearr** | Media analytics (TimescaleDB) |
| **Kometa** | Collection metadata |
| **TitleCardMaker** | Custom title cards |
| **Posterizarr** | Custom posters |

### Reading

| Service | What it does |
|---------|-------------|
| **Kavita** | Books, comics, manga |
| **Komga** | Comics and manga |
| **Mylar3** | Comic downloader |
| **Bookshelf** | Book management (Readarr fork) |
| **Audiobookshelf** | Audiobooks |
| **ReadMeABook** | Audiobook acquisition |

### Platform

| Service | What it does |
|---------|-------------|
| **Authentik** | SSO / identity provider |
| **PostgreSQL** | Shared database for arr apps, Grafana, Forgejo |
| **Prometheus + Grafana + Loki** | Metrics, dashboards, logs |
| **Uptime Kuma + AutoKuma** | Health checks (label-driven) |
| **Homepage** | Service dashboard (label-driven) |
| **Apprise** | Notification fan-out (Telegram, Discord) |
| **Forgejo + Woodpecker** | Git forge + CI/CD pipelines |
| **n8n** | Workflow automation |
| **Restic** | Offsite backups |

## Architecture

Three tiers, each depending on the one below:

```
┌─────────────────────────────────────────────┐
│  Infrastructure                             │
│  Caddy · 1Password Connect · Komodo         │
│  cloudflared · Step-CA              ← docker stack deploy
├─────────────────────────────────────────────┤
│  Platform                                   │
│  Authentik · PostgreSQL · Monitoring         │
│  Observability · CI/CD · n8n        ← Komodo ResourceSync
├─────────────────────────────────────────────┤
│  Application                                │
│  Media · Reading                    ← Komodo ResourceSync
└─────────────────────────────────────────────┘
```

Infrastructure bootstraps itself with `docker stack deploy`. Everything above it is managed declaratively through Komodo.

### Networking

```
Internet → Cloudflare Edge → cloudflared tunnel → Caddy → Authentik (forward auth) → Service
                                                    ↑
Internal clients → UniFi DNS (*.in.hypyr.space) ────┘
```

All inter-service communication uses Docker overlay networks. Services discover each other via DNS. The Docker socket is never exposed directly — every stack that needs it runs a [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy) sidecar.

### Storage

| Pool | Media | Purpose |
|------|-------|---------|
| **apps01** | SSD | All application data — configs, databases, secrets |
| **data01** | HDD | Bulk media library, download staging |

### Secrets

Zero secrets in this repo. Every stack has an `op-secrets` init job that runs `1password/op:2` with `op inject` to pull secrets from 1Password Connect at deploy time. Files land on disk owned `999:999` with mode `750`.

### Provisioning

```
OpenTofu (Proxmox VMs) → PXE boot → Ansible (harden + configure) → Swarm join → Komodo deploys
```

## Cloud Dependencies

| Service | Use | Cost |
|---------|-----|------|
| [Cloudflare](https://cloudflare.com) | DNS, tunnel, domain | ~$10/yr |
| [1Password](https://1password.com) | Secret management (Connect server) | ~$36/yr |
| [GitHub](https://github.com) | Repo hosting, CI, Renovate | Free |
| | | **~$4/mo** |

## Repo Structure

```
📂 stacks/
├── 📂 infrastructure/     Caddy, 1Password Connect, Komodo, cloudflared, PXE
├── 📂 platform/           Authentik, PostgreSQL, monitoring, CI/CD, backups, n8n
└── 📂 application/        Media (core/support/enrichment/torrent), Reading
📂 komodo/                  ResourceSync TOML — declarative stack management
📂 ansible/                 Node provisioning and hardening
📂 opentofu/                Proxmox VM definitions
📂 scripts/                 Validation, bootstrap, and deployment helpers
📂 docs/                    Architecture, ADRs, runbooks, storage maps
📂 config/                  Critical service definitions
📂 constitution/            Governance principles (AI agent guardrails)
📂 contracts/               Agent operating rules
📂 requirements/            Domain specifications
```

## Governance

This repo includes a governance layer for AI agents operating on the infrastructure — things like "don't restart Plex during a movie" and secret handling rules. If you're into that sort of thing: [`contracts/agents.md`](contracts/agents.md).

## Security

- Pre-commit hooks scan for secrets and PII: `mise run hooks:install`
- CI gate: `pii_secrets_gate` workflow
- Details: [`docs/security/pii-and-secrets.md`](docs/security/pii-and-secrets.md)

---

<div align="center">

*Coffee is too slow.*

</div>
