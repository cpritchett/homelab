# Tasks: Media Stack Migration (K8s to Docker Swarm)

**Input**: Design documents from `/specs/007-media-stack-migration/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not requested in feature specification. No test tasks generated.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure, validation script, and shared configuration

- [x] T001 Create application media directory structure: `stacks/application/media/`, `stacks/application/media/core/`, `stacks/application/media/support/`, `stacks/application/media/torrent/`
- [x] T002 Create pre-deployment validation script at `scripts/validate-media-setup.sh` — POSIX shell, checks Docker/Swarm running, proxy_network exists, op-connect network exists, op_connect_token secret exists, 1Password Connect reachable, /dev/dri exists, creates appdata directories under `/mnt/apps01/appdata/media/` with ownership 1701:1702
- [x] T003 Create media stack overview README at `stacks/application/media/README.md` — documents three-stack topology, shared patterns, deployment order

**Checkpoint**: Directory structure and validation script ready

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: DNS records and 1Password items that MUST exist before any stack can deploy

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create DNS CNAME records for active media services via UniFi API — `plex`, `sonarr`, `radarr`, `prowlarr`, `sabnzbd`, `bazarr`, `tautulli`, `maintainerr` all pointing to `barbary.in.hypyr.space`
- [x] T005 Verify existing 1Password items (`sonarr`, `radarr`, `prowlarr`, `sabnzbd`) have `api_key` field (can be empty initially) in `homelab` vault
- [x] T006 Create new 1Password item `plex-stack` in `homelab` vault with `claim_token` field (populate with fresh token from plex.tv/claim immediately before first deployment)
- [x] T007 Create ZFS appdata directories on TrueNAS: `sudo mkdir -p /mnt/apps01/appdata/media/{plex,sonarr,radarr,prowlarr,sabnzbd,bazarr,tautulli,maintainerr}/{config,secrets}` with ownership `1701:1702`
- [x] T008 Verify media data directory structure exists: `/mnt/data01/data/{downloads/{complete,incomplete},media/{tv,movies,music}}` with ownership `1701:1702`

**Checkpoint**: Foundation ready — all DNS, secrets, and storage prerequisites in place

---

## Phase 3: User Story 1 — Deploy Core Media Services (Priority: P1) 🎯 MVP

**Goal**: Deploy core media pipeline (Plex, Sonarr, Radarr, Prowlarr, SABnzbd) as a Docker Swarm stack with full label-driven infrastructure integration

**Independent Test**: Access each service at its `*.in.hypyr.space` URL. Verify Homepage shows "Media" group with all 5 services. Verify Uptime Kuma monitors report healthy. Trigger a search in Sonarr, verify it queries Prowlarr, sends to SABnzbd, completes to media library, and appears in Plex.

### Implementation for User Story 1

- [x] T009 [US1] Create 1Password secret template at `stacks/application/media/core/media.env.template` with `op://homelab/{item}/{field}` references for Plex claim, Sonarr/Radarr/Prowlarr/SABnzbd API keys
- [x] T010 [US1] Create core stack compose file at `stacks/application/media/core/compose.yaml` — define `op-secrets` replicated-job service using 1password/op:2 image with SHA-256 pin, OP_CONNECT_HOST, OP_CONNECT_TOKEN_FILE, template mount, secrets output to `/mnt/apps01/appdata/media/core/secrets/`
- [x] T011 [US1] Add Plex service to `stacks/application/media/core/compose.yaml` — linuxserver/plex image, port 32400, PUID=1701, PGID=1702, TZ=America/New_York, `/dev/dri:/dev/dri` GPU mount, config volume at `/mnt/apps01/appdata/media/plex/config:/config`, media volume at `/mnt/data01/data:/data`, secrets mount (read-only), deploy labels: Homepage (group: Media, widget: plex), Caddy (plex.in.hypyr.space, NO forward auth — Plex has own auth), AutoKuma (health check on `/web/index.html`)
- [x] T012 [P] [US1] Add Sonarr service to `stacks/application/media/core/compose.yaml` — linuxserver/sonarr image, port 8989, PUID/PGID/TZ, config at `/mnt/apps01/appdata/media/sonarr/config:/config`, media at `/mnt/data01/data:/data`, secrets mount, entrypoint wrapper to source env, deploy labels: Homepage (group: Media, widget: sonarr), Caddy (sonarr.in.hypyr.space + Authentik forward auth), AutoKuma (health check on `/ping`)
- [x] T013 [P] [US1] Add Radarr service to `stacks/application/media/core/compose.yaml` — linuxserver/radarr image, port 7878, same pattern as Sonarr with radarr-specific paths and labels, Caddy at radarr.in.hypyr.space, Homepage widget: radarr
- [x] T014 [P] [US1] Add Prowlarr service to `stacks/application/media/core/compose.yaml` — linuxserver/prowlarr image, port 9696, PUID/PGID/TZ, config at `/mnt/apps01/appdata/media/prowlarr/config:/config`, NO media data mount (indexer only), secrets mount, deploy labels: Homepage (group: Media, widget: prowlarr), Caddy (prowlarr.in.hypyr.space + Authentik forward auth), AutoKuma (health check on `/ping`)
- [x] T015 [P] [US1] Add SABnzbd service to `stacks/application/media/core/compose.yaml` — linuxserver/sabnzbd image, port 8080, PUID/PGID/TZ, config at `/mnt/apps01/appdata/media/sabnzbd/config:/config`, media at `/mnt/data01/data:/data`, secrets mount, deploy labels: Homepage (group: Media, widget: sabnzbd), Caddy (sabnzbd.in.hypyr.space + Authentik forward auth), AutoKuma (health check on `/api?mode=version`)
- [x] T016 [US1] Add networks and secrets sections to `stacks/application/media/core/compose.yaml` — define `proxy_network` (external), `media` (overlay), `op-connect` (external: op-connect_op-connect); define `op_connect_token` secret (external), `CLOUDFLARE_API_TOKEN` secret (external)
- [x] T017 [US1] Add Komodo stack resources to `komodo/resources.toml` — add `application_media_core` stack with swarm = "homelab-swarm", linked_repo = "homelab-repo", run_directory = "stacks/application/media/core", auto_pull = true, webhook_enabled = true, send_alerts = true, pre_deploy script = "scripts/validate-media-setup.sh"
- [x] T018 [US1] Create core stack README at `stacks/application/media/core/README.md` — documents services, ports, label configuration, secret template, deployment instructions
- [ ] T019 [US1] Run validation script on TrueNAS: `sudo sh scripts/validate-media-setup.sh` — verify all prerequisites pass
- [ ] T020 [US1] Deploy core stack via Komodo: `km --profile barbary execute deploy-stack application_media_core` — verify all 5 services + op-secrets show healthy in `docker service ls`
- [ ] T021 [US1] Verify core stack integration — confirm all 5 services accessible at `*.in.hypyr.space` URLs, Homepage shows "Media" group, AutoKuma creates monitors in Uptime Kuma, Plex hardware transcoding works (`/dev/dri` accessible in container)
- [ ] T022 [US1] Configure core services post-deployment — Plex: complete setup wizard, add media library; Prowlarr: add indexers; Sonarr: add Prowlarr + SABnzbd, set root folder `/data/media/tv`; Radarr: add Prowlarr + SABnzbd, set root folder `/data/media/movies`; SABnzbd: configure Usenet servers
- [ ] T023 [US1] Extract generated API keys from each service and store back to 1Password items (sonarr/api_key, radarr/api_key, prowlarr/api_key, sabnzbd/api_key)

**Checkpoint**: Core media pipeline fully functional — Prowlarr → Sonarr/Radarr → SABnzbd → Plex workflow operational

---

## Phase 4: User Story 2 — Deploy Supporting Media Services (Priority: P2)

**Goal**: Deploy supporting services (Bazarr, Tautulli, Maintainerr) that enhance the core pipeline

**Independent Test**: Access each service at its `*.in.hypyr.space` URL. Verify Bazarr connects to Sonarr/Radarr, Tautulli shows Plex activity, Maintainerr shows library rules.

### Implementation for User Story 2

- [x] T024 [US2] Create support stack compose file at `stacks/application/media/support/compose.yaml` — NO op-secrets job needed (no 1Password secrets)
- [x] T025 [P] [US2] Add Bazarr service to `stacks/application/media/support/compose.yaml` — linuxserver/bazarr image, port 6767, PUID=1701, PGID=1702, TZ=America/New_York, config at `/mnt/apps01/appdata/media/bazarr/config:/config`, media at `/mnt/data01/data:/data`, deploy labels: Homepage (group: Media, widget: bazarr), Caddy (bazarr.in.hypyr.space + Authentik forward auth), AutoKuma (health check on `/ping`)
- [x] T026 [P] [US2] Add Tautulli service to `stacks/application/media/support/compose.yaml` — linuxserver/tautulli image, port 8181, PUID/PGID/TZ, config at `/mnt/apps01/appdata/media/tautulli/config:/config`, NO media data mount (API-only), deploy labels: Homepage (group: Media, widget: tautulli), Caddy (tautulli.in.hypyr.space + Authentik forward auth), AutoKuma (health check on `/status`)
- [x] T027 [P] [US2] Add Maintainerr service to `stacks/application/media/support/compose.yaml` — ghcr.io/jorenn92/maintainerr image, port 6246, user 1701:1702 via `user:` directive (not LinuxServer image), config at `/mnt/apps01/appdata/media/maintainerr/config:/opt/data`, NO media data mount (API-only), deploy labels: Homepage (group: Media, widget: customapi), Caddy (maintainerr.in.hypyr.space + Authentik forward auth), AutoKuma (health check on `/`)
- [x] T028 [US2] Add networks section to `stacks/application/media/support/compose.yaml` — define `proxy_network` (external), `media_support` (overlay); add `CLOUDFLARE_API_TOKEN` secret (external)
- [x] T029 [US2] Add `application_media_support` stack resource to `komodo/resources.toml` — same pattern as core stack, run_directory = "stacks/application/media/support", pre_deploy script = "scripts/validate-media-setup.sh"
- [x] T030 [US2] Create support stack README at `stacks/application/media/support/README.md`
- [ ] T031 [US2] Deploy support stack via Komodo: `km --profile barbary execute deploy-stack application_media_support` — verify all 3 services show healthy
- [ ] T032 [US2] Verify support stack integration — confirm all 3 services accessible at `*.in.hypyr.space` URLs, Homepage shows them in "Media" group, AutoKuma creates monitors
- [ ] T033 [US2] Configure support services post-deployment — Bazarr: connect to Sonarr and Radarr using API keys, configure subtitle providers; Tautulli: connect to Plex server; Maintainerr: connect to Plex, Sonarr, Radarr

**Checkpoint**: All 8 active media services deployed, configured, and monitored

---

## Phase 5: User Story 3 — Prepare Torrent Stack (Priority: P3)

**Goal**: Create compose files, secret template, and labels for the torrent stack (qBittorrent, Cross-Seed, Autobrr, Recyclarr). Files are validated but NOT deployed (VPN dependency).

**Independent Test**: Run `docker compose -f stacks/application/media/torrent/compose.yaml config` — no syntax errors. Verify 1Password items exist with required fields. Run validation script — all label checks pass.

### Implementation for User Story 3

- [x] T034 [US3] Create torrent secret template at `stacks/application/media/torrent/torrent.env.template` with `op://homelab/{item}/{field}` references for Autobrr API key, session secret, Recyclarr API key
- [x] T035 [US3] Create torrent stack compose file at `stacks/application/media/torrent/compose.yaml` — define `op-secrets` replicated-job (same pattern as core stack), add comment header noting VPN dependency and deferred deployment status
- [x] T036 [P] [US3] Add qBittorrent service to `stacks/application/media/torrent/compose.yaml` — linuxserver/qbittorrent image, port 8080, PUID/PGID/TZ, config at `/mnt/apps01/appdata/media/qbittorrent/config:/config`, media at `/mnt/data01/data:/data`, deploy labels: Homepage (group: Media, widget: qbittorrent), Caddy (qbittorrent.in.hypyr.space + Authentik forward auth), AutoKuma; add TODO comment for VPN sidecar
- [x] T037 [P] [US3] Add Cross-Seed service to `stacks/application/media/torrent/compose.yaml` — ghcr.io/cross-seed/cross-seed image, port 2468, config at `/mnt/apps01/appdata/media/cross-seed/config:/config`, media at `/mnt/data01/data:/data`, deploy labels: Homepage (group: Media, widget: customapi), Caddy (cross-seed.in.hypyr.space + Authentik forward auth), AutoKuma
- [x] T038 [P] [US3] Add Autobrr service to `stacks/application/media/torrent/compose.yaml` — ghcr.io/autobrr/autobrr image, port 7474, config at `/mnt/apps01/appdata/media/autobrr/config:/config`, secrets mount, entrypoint wrapper, deploy labels: Homepage (group: Media, widget: autobrr), Caddy (autobrr.in.hypyr.space + Authentik forward auth), AutoKuma (health check on `/api/healthz/liveness`)
- [x] T039 [P] [US3] Add Recyclarr service to `stacks/application/media/torrent/compose.yaml` — ghcr.io/recyclarr/recyclarr image, daemon mode (built-in scheduler), config at `/mnt/apps01/appdata/media/recyclarr/config:/config`, secrets mount, NO web UI, NO Caddy/Homepage/AutoKuma labels, PUID/PGID/TZ
- [x] T040 [US3] Add networks, secrets sections to `stacks/application/media/torrent/compose.yaml` — define `proxy_network` (external), `media_torrent` (overlay), `op-connect` (external); define `op_connect_token` and `CLOUDFLARE_API_TOKEN` secrets (external)
- [x] T041 [US3] Create torrent stack README at `stacks/application/media/torrent/README.md` — document deferred status, VPN dependency, deployment instructions for when VPN is ready
- [x] T042 [US3] Validate torrent compose file syntax: `docker compose -f stacks/application/media/torrent/compose.yaml config` — verify no errors
- [ ] T043 [US3] Verify existing 1Password items (`autobrr`, `recyclarr`) have required fields in `homelab` vault

**Checkpoint**: Torrent stack files are validated, reviewed, and ready for deployment once VPN design is finalized

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final integration, documentation, and commit/push

- [x] T044 [P] Update `stacks/application/media/README.md` with links to all three stack READMEs and final deployment status
- [ ] T045 Update Homepage widget API key labels in core compose file — after API keys are stored in 1Password (T023), add `homepage.widget.key` labels referencing `{{HOMEPAGE_VAR_*}}` variables, update Homepage env template to include media service API key references
- [ ] T046 Commit all changes and push to `007-media-stack-migration` branch
- [ ] T047 Create pull request for merge to main

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2)
- **User Story 2 (Phase 4)**: Depends on Foundational (Phase 2) + User Story 1 core services running (for Bazarr/Tautulli/Maintainerr to connect)
- **User Story 3 (Phase 5)**: Depends on Foundational (Phase 2) only — can run in parallel with US1 (compose files only, no deployment)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **User Story 2 (P2)**: Requires US1 core services deployed and running (Bazarr needs Sonarr/Radarr, Tautulli needs Plex)
- **User Story 3 (P3)**: No runtime dependencies — compose file creation can happen in parallel with US1/US2

### Within Each User Story

- Secret template before compose file
- Compose file services before networks/secrets sections
- Komodo resource before deployment
- Deployment before verification
- Verification before post-deployment configuration

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel after T001
- **Phase 2**: T004, T005, T006, T007, T008 can all run in parallel
- **Phase 3 (US1)**: T012, T013, T014, T015 can run in parallel (different services, same compose file — add sequentially or merge)
- **Phase 4 (US2)**: T025, T026, T027 can run in parallel (different services)
- **Phase 5 (US3)**: T036, T037, T038, T039 can run in parallel (different services)
- **Cross-story**: US3 (compose files only) can run in parallel with US1/US2

---

## Parallel Example: User Story 1

```bash
# After T010 (compose file created with op-secrets), add services in parallel:
Task: "Add Sonarr service to compose.yaml"      # T012
Task: "Add Radarr service to compose.yaml"       # T013
Task: "Add Prowlarr service to compose.yaml"     # T014
Task: "Add SABnzbd service to compose.yaml"      # T015
# Note: Since all write to the same compose file, these are logically parallel
# but should be applied sequentially to avoid conflicts
```

## Parallel Example: User Story 3 (alongside US1)

```bash
# US3 compose files can be created while US1 is deploying:
Task: "Create torrent secret template"           # T034
Task: "Create torrent compose file"              # T035
Task: "Add qBittorrent service"                  # T036
Task: "Add Cross-Seed service"                   # T037
Task: "Add Autobrr service"                      # T038
Task: "Add Recyclarr service"                    # T039
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004–T008)
3. Complete Phase 3: User Story 1 (T009–T023)
4. **STOP and VALIDATE**: Verify core pipeline end-to-end (Prowlarr → Sonarr → SABnzbd → Plex)
5. Core media pipeline operational — MVP achieved

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. User Story 1 → Core pipeline operational (MVP)
3. User Story 2 → Supporting services enhance pipeline
4. User Story 3 → Torrent stack prepared for future VPN deployment
5. Polish → API key widgets, documentation, PR

### Suggested MVP Scope

**User Story 1 only** (T001–T023, 23 tasks). This delivers the complete media acquisition pipeline:
- Plex for playback with hardware transcoding
- Sonarr + Radarr for media management
- Prowlarr for indexer management
- SABnzbd for downloads
- Full label-driven integration (Homepage, Caddy, AutoKuma, Authentik)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Services in the same compose file are marked [P] for logical parallelism but should be written sequentially
- API keys for Homepage widgets are generated AFTER first deployment — a second compose update is needed (T045)
- Plex claim token expires in 4 minutes — generate at plex.tv/claim immediately before T020
- Torrent stack (US3) creates files only — NO deployment until VPN design is finalized
- Commit after each phase or logical group of tasks
