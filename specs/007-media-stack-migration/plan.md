# Implementation Plan: Media Stack Migration (K8s to Docker Swarm)

**Branch**: `007-media-stack-migration` | **Date**: 2026-02-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-media-stack-migration/spec.md`

## Summary

Deploy 12 media applications as three Docker Swarm stacks on TrueNAS, replacing Kubernetes HelmReleases with Docker Compose files following the label-driven infrastructure pattern (spec 002). Core pipeline (Plex, Sonarr, Radarr, Prowlarr, SABnzbd), supporting services (Bazarr, Tautulli, Maintainerr), and torrent stack (qBittorrent, Cross-Seed, Autobrr, Recyclarr) are deployed independently. This is a greenfield deployment with no data migration — services start fresh and are configured after deployment.

## Technical Context

**Language/Version**: POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files
**Primary Dependencies**: Docker Swarm (orchestration), Caddy + caddy-docker-proxy (ingress), Homepage (dashboard), AutoKuma 2.0.0 (monitoring bridge), Uptime Kuma (monitoring), Komodo (stack deployment), 1Password Connect (secrets), Authentik (SSO)
**Storage**: TrueNAS host paths — `/mnt/apps01/appdata/media/<service>/` (application config), `/mnt/data01/data` (media files); Docker overlay networks for service communication
**Testing**: Pre-deployment validation scripts (`scripts/validate-media-setup.sh`), POSIX-compatible, < 10s execution
**Target Platform**: Docker Swarm on TrueNAS (Linux/amd64)
**Project Type**: Infrastructure-as-Code (Docker Compose stacks + shell scripts)
**Performance Goals**: All services healthy within 5 minutes of deployment; Plex QuickSync transcoding functional
**Constraints**: All secrets via 1Password Connect (no plaintext on disk); Komodo-managed deployment; labels under `deploy.labels`; user/group 1701:1702 for all services; Plex requires `/dev/dri` GPU passthrough
**Scale/Scope**: 12 services across 3 stacks (core: 5, support: 3, torrent: 4 deferred)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle Compliance

| Principle | Status | Notes |
|-----------|--------|-------|
| 1. Management is Sacred and Boring | PASS | No changes to management network; media services on TrueNAS, not management VLAN |
| 2. DNS Encodes Intent | PASS | Internal services use `*.in.hypyr.space`; no public zone changes |
| 3. External Access is Identity-Gated | PASS | All access via Caddy with Authentik forward auth (except Plex which uses its own auth) |
| 4. Routing Does Not Imply Permission | PASS | Network segmentation via overlay networks; media services on internal overlays |
| 5. Prefer Structural Safety Over Convention | PASS | Label-driven pattern enforced via ADR-0034; pre-deployment validation scripts |

### Hard-Stop Check

| Hard-Stop | Triggered? | Notes |
|-----------|-----------|-------|
| Expose services directly to WAN | NO | All ingress via Caddy reverse proxy with TLS |
| Publish `in.hypyr.space` publicly | NO | Internal zone remains internal DNS only |
| Allow non-console access to Management | NO | No management VLAN involvement |
| Install overlay agents on Management VLAN | NO | Docker Swarm is on TrueNAS, not management |
| Override public FQDN to bypass Cloudflare Access | NO | No split-horizon overrides |

### Invariant Check

| Invariant | Status | Notes |
|-----------|--------|-------|
| Secrets: 1Password single source of truth | PASS | All stacks use `op-connect` + `op inject` pattern (ADR-0035) |
| Secrets: No plaintext on disk | PASS | One-shot job hydration, never pre-materialized |
| Repository: NAS stacks Komodo-managed | PASS | All three stacks deployed via Komodo |
| Repository: Markdown on allowlist | PASS | All docs in permitted `specs/007-*/` paths |
| Repository: Deployment targets separated | PASS | All Swarm stacks under `stacks/application/media/` |

**GATE RESULT: PASS** — No violations. Proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/007-media-stack-migration/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
├── checklists/          # Quality validation
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
stacks/application/media/
├── core/                              # Stack: application_media_core
│   ├── compose.yaml                   # Plex, Sonarr, Radarr, Prowlarr, SABnzbd + op-secrets
│   ├── media.env.template             # 1Password op inject template
│   └── README.md                      # Stack documentation
├── support/                           # Stack: application_media_support
│   ├── compose.yaml                   # Bazarr, Tautulli, Maintainerr
│   └── README.md
├── torrent/                           # Stack: application_media_torrent (deferred)
│   ├── compose.yaml                   # qBittorrent, Cross-Seed, Autobrr, Recyclarr
│   ├── torrent.env.template           # 1Password op inject template
│   └── README.md
└── README.md                          # Media stack overview

scripts/
└── validate-media-setup.sh            # Pre-deployment validation

komodo/
└── resources.toml                     # Updated with 3 new stack resources
```

**Structure Decision**: Infrastructure-as-Code layout extending `stacks/` with a new `application/media/` directory containing three sub-stacks. Each sub-stack is self-contained with its own compose file. All three share a common overlay network for inter-service communication.

## Complexity Tracking

> No constitution violations detected. No complexity justifications required.
