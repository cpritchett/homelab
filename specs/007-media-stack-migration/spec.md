# Feature Specification: Media Stack Migration (K8s to Docker Swarm)

**Feature Branch**: `007-media-stack-migration`
**Created**: 2026-02-11
**Status**: Draft
**Input**: ADR-0033 Phase 3 — Migrate 12 media applications from Kubernetes HelmReleases to Docker Swarm stacks on TrueNAS
**Relates to**: ADR-0033, spec 002 (label-driven swarm infrastructure)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Core Media Services (Priority: P1)

As a homelab operator, I want my core media pipeline (Plex, Sonarr, Radarr, Prowlarr, SABnzbd) running on Docker Swarm so that media acquisition and playback work end-to-end without Kubernetes dependencies.

**Why this priority**: These 5 services form the critical path for media automation. Prowlarr feeds indexers to Sonarr/Radarr, which send downloads to SABnzbd, which writes to the shared media library that Plex serves. Without this pipeline, no media flows.

**Independent Test**: Trigger a search in Sonarr, verify it queries Prowlarr, sends to SABnzbd for download, completes to the media library, and appears in Plex. Access each service at its `*.in.hypyr.space` URL through Caddy with Authentik SSO.

**Acceptance Scenarios**:

1. **Given** the media stack is deployed on Swarm, **When** I navigate to `sonarr.in.hypyr.space`, **Then** I am authenticated via Authentik and can access Sonarr
2. **Given** Prowlarr is configured with indexers, **When** Sonarr searches for a series, **Then** Prowlarr returns results and Sonarr can send downloads to SABnzbd
3. **Given** SABnzbd completes a download, **When** the file is post-processed, **Then** it appears in the correct path under `/mnt/data01/data` and Plex detects it
4. **Given** Plex is running on Swarm, **When** a user streams media, **Then** hardware transcoding via Intel QuickSync functions correctly
5. **Given** all 5 services are deployed, **When** I check the Homepage dashboard, **Then** each service appears in a "Media" group with working widgets
6. **Given** all 5 services are deployed, **When** I check Uptime Kuma, **Then** monitors exist and report healthy for each service

---

### User Story 2 - Deploy Supporting Media Services (Priority: P2)

As a homelab operator, I want supporting media services (Bazarr, Tautulli, Maintainerr) running on Docker Swarm so that subtitle management, Plex analytics, and library maintenance are available.

**Why this priority**: These services enhance the media experience but are not required for the core acquisition-to-playback pipeline. They can be deployed independently after the core services are operational.

**Independent Test**: Access each service at its `*.in.hypyr.space` URL, verify it connects to its upstream dependency (Bazarr to Sonarr/Radarr, Tautulli to Plex, Maintainerr to Plex/Sonarr/Radarr).

**Acceptance Scenarios**:

1. **Given** Bazarr is deployed, **When** I open `bazarr.in.hypyr.space`, **Then** it is connected to Sonarr and Radarr and can search for subtitles
2. **Given** Tautulli is deployed, **When** I open `tautulli.in.hypyr.space`, **Then** it shows Plex activity history and current streams
3. **Given** Maintainerr is deployed, **When** I open `maintainerr.in.hypyr.space`, **Then** it shows configured rules for library maintenance

---

### User Story 3 - Prepare Torrent Stack for Future Deployment (Priority: P3)

As a homelab operator, I want Docker Compose files and 1Password items prepared for the torrent stack (qBittorrent, Cross-Seed, Autobrr, Recyclarr) so that when the VPN design is finalized, deployment is a single command.

**Why this priority**: These services are currently suspended in Kubernetes pending VPN sidecar design. The compose files, secret templates, and label configurations should be ready so deployment is trivial once the VPN decision is made. No actual deployment occurs in this story.

**Independent Test**: Validate compose files pass `docker compose config` syntax check. Verify 1Password items exist with required fields. Confirm label patterns match ADR-0034 governance requirements.

**Acceptance Scenarios**:

1. **Given** compose files are written for the torrent stack, **When** I run `docker compose config`, **Then** no syntax errors are reported
2. **Given** 1Password items exist for torrent services, **When** secret templates reference them, **Then** `op inject` resolves all references without errors
3. **Given** compose labels follow ADR-0034, **When** the validation script runs, **Then** all services pass label compliance

---

### Edge Cases

- What happens if Plex hardware transcoding fails because the GPU device is not passed through to the Swarm service? Deployment must verify `/dev/dri` device access.
- What happens if the NFS media mount path differs between k8s and Swarm? Both use `/mnt/data01/data` — the NFS mount is on the TrueNAS host itself, so Swarm bind-mounts it directly (no NFS client needed).
- What happens if a service's 1Password item is missing required fields? The pre-deployment validation script must check all items before deployment.
- What happens if Plex's claim token expires before initial setup? A fresh claim token must be generated from plex.tv and injected at first boot.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each media service MUST be deployed as a Docker Swarm stack with a compose file under `stacks/application/media/`
- **FR-002**: Each service MUST have Caddy reverse proxy labels for TLS termination at `<service>.in.hypyr.space`
- **FR-003**: Each service MUST have Authentik forward auth labels to enforce SSO (except Plex, which uses its own authentication)
- **FR-004**: Each service MUST have Homepage labels for dashboard auto-discovery in a "Media" group
- **FR-005**: Each service MUST have AutoKuma labels for uptime monitoring
- **FR-006**: Services requiring secrets MUST use the one-shot `replicated-job` hydration pattern (ADR-0035) with 1Password Connect
- **FR-007**: All services MUST run as user 1701, group 1702 to match existing file ownership on the media datasets
- **FR-008**: All services MUST mount `/mnt/data01/data` for shared media file access
- **FR-009**: Application config data MUST be stored on ZFS datasets under `/mnt/apps01/appdata/media/<service>/`
- **FR-010**: Plex MUST have access to the Intel GPU device (`/dev/dri`) for hardware transcoding
- **FR-011**: Inter-service communication (e.g., Sonarr to Prowlarr, Sonarr to SABnzbd) MUST use Swarm service DNS names on an internal overlay network
- **FR-012**: Torrent stack compose files MUST be created but NOT deployed (marked with comments indicating VPN dependency)
- **FR-013**: A pre-deployment validation script MUST verify all prerequisites (ZFS datasets, 1Password items, network connectivity) before deployment
- **FR-014**: Recyclarr MUST be configured as a scheduled task (cron-equivalent in Swarm) rather than a long-running service

### Key Entities

- **Media Service**: An application in the media pipeline (Plex, Sonarr, Radarr, etc.) with its compose file, secret template, labels, and ZFS dataset
- **Media Stack**: A Docker Swarm stack grouping related media services that share an overlay network and can be deployed/updated together
- **Secret Template**: An `op inject` template file mapping 1Password item fields to environment variables for a service
- **ZFS Dataset**: A TrueNAS filesystem dataset storing application config data, with appropriate permissions and snapshot policies

## Assumptions

- The TrueNAS Docker Swarm infrastructure (op-connect, Komodo, Caddy, Authentik) is fully operational (verified by spec 002)
- This is a greenfield deployment — no existing configuration data needs to be migrated from Kubernetes
- 1Password items for media services will be created fresh (some may already exist from prior k8s deployment)
- Media files on `/mnt/data01/data` are already on TrueNAS — no media data migration needed
- Plex authentication is handled by Plex's own account system, not Authentik forward auth
- Services will be deployed as a single Swarm stack (`application_media`) rather than individual stacks per service, to share an internal overlay network
- Each service will require initial setup and configuration after first deployment (indexers, download clients, library paths, etc.)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 8 active media services are accessible at their `*.in.hypyr.space` URLs with valid TLS certificates and SSO authentication
- **SC-002**: The Prowlarr-to-Sonarr/Radarr-to-SABnzbd-to-Plex pipeline completes an end-to-end media acquisition within the same timeframe as the Kubernetes deployment
- **SC-003**: Plex hardware transcoding completes a 1080p-to-720p transcode test using Intel QuickSync
- **SC-004**: All 8 active services appear in the Homepage dashboard "Media" group with appropriate widgets
- **SC-005**: Uptime Kuma monitors report all 8 active services as healthy for 24 hours after deployment
- **SC-006**: All services can be configured and connected to each other (Prowlarr indexers, Sonarr/Radarr download clients, Plex libraries) within a single setup session
- **SC-007**: 4 torrent stack compose files pass syntax validation and secret template injection tests without deployment
