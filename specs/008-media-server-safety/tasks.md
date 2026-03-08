# Tasks: Critical Service Production Safety

**Input**: Design documents from `/specs/008-media-server-safety/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Not requested in spec. Manual verification via quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Create the critical service registry and obtain API tokens

- [ ] T001 Create critical service registry file at config/critical-services.yaml with Plex and Jellyfin entries per data-model.md schema
- [ ] T002 [P] Create 1Password item `plex` in homelab vault with field `X_PLEX_TOKEN` (obtain token from Plex server at /mnt/apps01/appdata/media/plex/config/Library/Application Support/Plex Media Server/Preferences.xml)
- [ ] T003 [P] Create 1Password item `jellyfin` in homelab vault with field `API_KEY` (generate API key in Jellyfin admin dashboard at https://jellyfin.in.hypyr.space)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Update governance documents that all agent sessions must follow

**CRITICAL**: No deploy skill changes can take effect until governance docs are updated

- [ ] T004 Add critical service safety rule to contracts/agents.md — add a "Required: Critical Service Safety" section under Required Workflows stating agents MUST check config/critical-services.yaml before deploying stacks containing critical services
- [ ] T005 [P] Update agent memory at /Users/cpritchett/.claude/projects/-Users-cpritchett-src-personal-homelab/memory/MEMORY.md — verify critical service constraint is documented (already partially done; ensure it references config/critical-services.yaml)
- [ ] T014 [P] Update constitution/amendments/ — create AMENDMENT-NNNN-critical-service-safety.md documenting the new agent operating rule (reference ADR format)

**Checkpoint**: Governance documents updated — agent sessions will read these on startup

---

## Phase 3: User Story 1 + 2 — Session Check + Critical Service Annotation (Priority: P1) MVP

**Goal**: Agent checks for active Plex/Jellyfin sessions before deploying application_media_core and blocks deploy if sessions are active. Agent reads critical service annotations from config/critical-services.yaml.

**Independent Test**: Start playing media on Plex or Jellyfin. Ask agent to deploy application_media_core. Verify agent reports active sessions and blocks the deploy. Stop playback, retry, verify deploy proceeds.

### Implementation for User Stories 1 + 2

- [ ] T006 [US1] [US2] Update komodo-deploy skill (Claude Code project setting, not a repo file) to add pre-deploy session check logic — before executing `km deploy-stack`, read config/critical-services.yaml, identify if the target stack contains critical services, and if so query each service's session API
- [ ] T007 [US1] [US2] Add session-check curl commands to the komodo-deploy skill — for Plex: GET /status/sessions?X-Plex-Token={token} (query parameter), parse MediaContainer.size and Player.state; for Jellyfin: GET /Sessions?ApiKey={key} (query parameter), filter entries where NowPlayingItem is present. Report active session count, usernames, and media titles per contracts/session-check-api.md
- [ ] T008 [US1] [US2] Add blocking logic to komodo-deploy skill — when active sessions detected, present session details to operator and ask for confirmation before proceeding. Format: "N active streams on ServiceName (user1: Title [playing], user2: Title [paused]). Deploy will restart ServiceName. Proceed anyway?"
- [ ] T009 [US1] [US2] Add unreachable/error handling to komodo-deploy skill — if session API returns non-200, connection timeout, or is unreachable, treat as "may be active" and ask operator per FR-005. Display the specific error (401 = bad token, timeout = service down, etc.)

**Checkpoint**: Agent blocks media core deploys when streams are active and reads critical services from config file

---

## Phase 4: User Story 3 — Operator Override (Priority: P2)

**Goal**: Operator can explicitly override the session check and force a deploy when streams are active

**Independent Test**: With an active stream, tell the agent "yes" when prompted. Verify deploy proceeds and the override is noted in the deploy output.

### Implementation for User Story 3

- [ ] T010 [US3] Ensure komodo-deploy skill accepts operator confirmation ("yes", "proceed", "override") to bypass the session check block — this should already work from T008's confirmation prompt; verify the flow logs the override decision
- [ ] T011 [US3] Add override logging to komodo-deploy skill — when operator overrides, include in the deploy output: "Session check overridden by operator. N active sessions on ServiceName at time of deploy."

**Checkpoint**: Operator can override session check with explicit confirmation

---

## Phase 5: User Story 4 — Non-Critical Passthrough (Priority: P3)

**Goal**: Deploys that don't affect critical services proceed without session checks

**Independent Test**: Deploy platform_monitoring or any stack not containing critical services. Verify no session check is triggered.

### Implementation for User Story 4

- [ ] T012 [US4] Verify komodo-deploy skill only triggers session checks when target stack matches a critical service's `stack` or `cross_stack_deps` in config/critical-services.yaml — non-matching stacks should skip the check entirely with no user-visible prompt
- [ ] T013 [US4] Add brief log line to komodo-deploy skill when session check is skipped: "No critical services in stack {name}, proceeding" (visible only in verbose/debug mode, not as a prompt to the operator)

**Checkpoint**: Non-critical stack deploys proceed without interruption

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and end-to-end verification

- [ ] T015 [P] Update specs/008-media-server-safety/spec.md status from Draft to Implemented
- [ ] T016 Run quickstart.md end-to-end verification: play media on Plex, attempt deploy, verify block; confirm override; stop playback, verify clean deploy; deploy non-critical stack, verify no check

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories 1+2 (Phase 3)**: Depend on Phase 1 (config file + API tokens) and Phase 2 (governance docs)
- **User Story 3 (Phase 4)**: Depends on Phase 3 (override builds on blocking logic)
- **User Story 4 (Phase 5)**: Depends on Phase 3 (passthrough tests the check-skip path)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Stories 1 + 2 (P1)**: Combined because the annotation mechanism and the session check are tightly coupled in the skill implementation. Can start after Phase 2.
- **User Story 3 (P2)**: Builds on the blocking logic from US1/US2. Requires Phase 3 complete.
- **User Story 4 (P3)**: Validates the skip path. Requires Phase 3 complete. Can run in parallel with US3.

### Parallel Opportunities

- T002 and T003 (1Password items) can run in parallel
- T004, T005, and T014 (governance docs + amendment) can run in parallel
- Phase 4 (US3) and Phase 5 (US4) can run in parallel after Phase 3

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (config file + API tokens)
2. Complete Phase 2: Foundational (governance docs)
3. Complete Phase 3: User Stories 1 + 2 (session check + annotation)
4. **STOP and VALIDATE**: Test with active Plex/Jellyfin stream
5. This alone provides the core safety constraint

### Incremental Delivery

1. Setup + Foundational → Config and governance ready
2. US1 + US2 → Session check works, streams protected (MVP!)
3. US3 → Operator override for emergencies
4. US4 → Clean passthrough for non-critical stacks
5. Polish → Status update, full verification

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US2 are combined in Phase 3 because the critical service registry (US2) and the session check (US1) are implemented together in the komodo-deploy skill
- The komodo-deploy skill is the primary implementation target — most tasks modify this single skill file
- 1Password items require either biometric auth (op CLI) or manual creation in the 1Password web UI
- Commit after each phase completion
