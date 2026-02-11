# Tasks: Label-Driven Docker Swarm Infrastructure

**Input**: Design documents from `/specs/002-label-driven-swarm-infrastructure/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested in the feature spec. Validation scripts serve as the testing mechanism for this infrastructure-as-code project.

**Organization**: Tasks are grouped by user story (remaining workstreams from spec.md) to enable independent implementation and deployment of each.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Stacks**: `stacks/infrastructure/` (Tier 1), `stacks/platform/` (Tier 2)
- **Scripts**: `scripts/validate-*.sh` (pre-deployment validation)
- **Governance**: `docs/adr/`, `docs/governance/`
- **Specs**: `specs/002-label-driven-swarm-infrastructure/`

---

## Phase 1: Setup (Shared Infrastructure Verification)

**Purpose**: Verify existing infrastructure tier is operational and prerequisites are met for all remaining user stories

- [x] T001 Verify infrastructure tier services are running (op-connect, Komodo, Caddy) by checking `docker service ls` on TrueNAS
- [x] T002 Verify external overlay networks exist (`proxy_network`, `op-connect_op-connect`) by running `docker network inspect` on TrueNAS
- [x] T003 Verify Docker Swarm secrets are present (`op_connect_token`, `CLOUDFLARE_API_TOKEN`) by running `docker secret ls` on TrueNAS
- [x] T004 Verify 1Password Connect API is reachable from Swarm services by testing `http://op-connect-api:8080/health`

---

## Phase 2: Foundational (1Password Items & Shared Secrets)

**Purpose**: Create all 1Password vault items required by user stories. These MUST be complete before any stack deployment.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 Create 1Password item `authentik-stack` in `homelab` vault with fields: `secret_key` (generate via `openssl rand -base64 50`), `bootstrap_email`, `bootstrap_password`, `postgres_password`, `homepage_api_key` (generate via `openssl rand -hex 32`)
- [x] T006 [P] Create 1Password item `monitoring-stack` in `homelab` vault with fields: `grafana_admin_user`, `grafana_admin_password`
- [x] T007 [P] Create 1Password item `cloudflare-tunnel` in `homelab` vault with fields: `tunnel_id`, `credentials_json` (store base64-encoded tunnel credentials)
- [x] T008 [P] Create Cloudflare Tunnel on workstation via `cloudflared tunnel create homelab` and capture credentials JSON for T007

**Checkpoint**: All 1Password items created and verified. Stack deployments can now proceed.

---

## Phase 3: User Story 1 - Deploy Authentik SSO Platform (Priority: P1)

**Goal**: Deploy Authentik SSO with label-driven auto-discovery for ingress (Caddy), dashboard (Homepage), and monitoring (AutoKuma). Enable forward authentication for downstream services.

**Independent Test**: Access `https://auth.in.hypyr.space`, complete initial admin setup, verify service appears in Homepage dashboard and Uptime Kuma monitors.

### Implementation for User Story 1

- [x] T009 [US1] Verify Authentik compose file has correct `deploy.labels` for Homepage, Caddy, and AutoKuma in `stacks/platform/auth/authentik/compose.yaml`
- [x] T010 [US1] Verify Authentik secret hydration job uses `replicated-job` mode with `restart_policy.condition: none` per ADR-0035 in `stacks/platform/auth/authentik/compose.yaml`
- [x] T011 [US1] Verify Authentik env templates use correct `op://homelab/authentik-stack/*` references in `stacks/platform/auth/authentik/env.template` and `stacks/platform/auth/authentik/postgres.template`
- [x] T012 [US1] Verify Authentik network configuration: server on `authentik` + `proxy_network`, PostgreSQL/Redis on `authentik` only, secrets-init on `op-connect` in `stacks/platform/auth/authentik/compose.yaml`
- [x] T013 [US1] Run pre-deployment validation script to verify all prerequisites in `scripts/validate-authentik-setup.sh`
- [x] T014 [US1] Deploy Authentik stack via Komodo UI and verify all services reach running state (`authentik-server` 1/1, `authentik-worker` 1/1, `postgresql` 1/1, `redis` 1/1, `secrets-init` 0/1 completed)
- [x] T015 [US1] Verify Caddy auto-discovery: TLS certificate issued for `auth.in.hypyr.space` and service accessible via HTTPS
- [x] T016 [US1] Verify Homepage auto-discovery: Authentik appears in correct dashboard group with widget
- [x] T017 [US1] Verify AutoKuma auto-discovery: monitor created with "autokuma" tag for Authentik in Uptime Kuma
- [x] T018 [US1] Authentik initial setup automated: admin account via `AUTHENTIK_BOOTSTRAP_*` env vars, default flows built-in, Homepage API token via blueprint (`blueprints/homepage-token.yaml.template`), forward auth via blueprint pattern (`blueprints/forward-auth-grafana.yaml`)
- [x] T019 [US1] Document forward auth label pattern for protecting downstream services in `stacks/docs/CADDY_FORWARD_AUTH_LABELS.md`

**Checkpoint**: Authentik SSO is operational at `https://auth.in.hypyr.space`, auto-discovered in Homepage and Uptime Kuma, with forward auth pattern documented for downstream services.

---

## Phase 4: User Story 2 - Deploy Monitoring Stack (Priority: P2)

**Goal**: Deploy Prometheus, Grafana, and Loki with label-driven auto-discovery. Provide metrics collection, log aggregation, and dashboards accessible via Caddy with TLS.

**Independent Test**: Access `https://grafana.in.hypyr.space`, login with admin credentials, verify Prometheus and Loki datasources are connected and scraping/ingesting data.

### Implementation for User Story 2

- [x] T020 [US2] Verify monitoring compose file has correct `deploy.labels` for all three services (Prometheus, Grafana, Loki) in `stacks/platform/monitoring/compose.yaml`
- [x] T021 [P] [US2] Verify `op-secrets` job uses `replicated-job` mode and references `grafana.env.template` correctly in `stacks/platform/monitoring/compose.yaml`
- [x] T022 [P] [US2] Verify Prometheus config has correct scrape targets for self-monitoring in `stacks/platform/monitoring/prometheus/prometheus.yml`
- [x] T023 [P] [US2] Verify Grafana provisioning has Prometheus and Loki datasources configured in `stacks/platform/monitoring/grafana/provisioning/datasources/datasources.yaml`
- [x] T024 [P] [US2] Verify Loki config uses filesystem storage with TSDB schema in `stacks/platform/monitoring/loki/loki-config.yaml`
- [x] T025 [US2] Run pre-deployment validation script to verify all prerequisites in `scripts/validate-monitoring-setup.sh`
- [x] T026 [US2] Deploy monitoring stack via Komodo UI and verify all services reach running state (`prometheus` 1/1, `grafana` 1/1, `loki` 1/1, `op-secrets` 0/1 completed)
- [x] T027 [US2] Verify Caddy auto-discovery: TLS certificates issued for `prometheus.in.hypyr.space`, `grafana.in.hypyr.space`, `loki.in.hypyr.space`
- [x] T028 [US2] Verify Homepage auto-discovery: all three monitoring services appear in "Monitoring" dashboard group with widgets
- [x] T029 [US2] Verify AutoKuma auto-discovery: monitors created for Prometheus (`/-/healthy`), Grafana (`/api/health`), and Loki (`/ready`)
- [x] T030 [US2] Login to Grafana, verify Prometheus datasource is connected and returning metrics
- [x] T031 [US2] Verify Loki datasource is connected in Grafana (log queries return results once log shipping is configured)

**Checkpoint**: Monitoring stack is operational. Prometheus scrapes self-metrics, Grafana dashboards accessible, Loki ready for log ingestion. All services auto-discovered in Homepage and Uptime Kuma.

---

## Phase 5: User Story 3 - Set Up Cloudflare Tunnel for External Webhooks (Priority: P3)

**Goal**: Deploy Cloudflare Tunnel as a Docker Swarm service to enable external access to services (e.g., GitHub webhooks to Komodo) without WAN port exposure, per ADR-0002.

**Independent Test**: Configure a GitHub webhook pointing to `https://komodo.hypyr.space/api/webhooks/github`, trigger it, and verify Komodo receives the event.

### Implementation for User Story 3

- [x] T032 [US3] Create Cloudflare Tunnel compose file with label-driven configuration (Homepage + AutoKuma labels, `replicated-job` secret hydration) — merged as sidecar into `stacks/infrastructure/caddy-compose.yaml`
- [x] T033 [P] [US3] Create tunnel secret template with `op://homelab/cloudflare-tunnel/*` references at `stacks/infrastructure/cloudflared-env.template`
- [x] T034 [P] [US3] Create tunnel ingress configuration routing `*.hypyr.space` to Caddy at `stacks/infrastructure/cloudflared-config.yaml`
- [x] T035 [US3] Create pre-deployment validation script for Cloudflare Tunnel at `scripts/validate-cloudflared-setup.sh`
- [x] T036 [US3] Configure Cloudflare DNS CNAME records pointing public FQDNs to tunnel via Cloudflare API (`komodo.hypyr.space` → tunnel)
- [x] T037 [US3] Deploy Cloudflare Tunnel as sidecar in Caddy stack and verify `cloudflared` service reaches running state (1/1)
- [x] T038 [US3] Verify tunnel connectivity: 4 QUIC connections registered to Cloudflare edge, `https://komodo.hypyr.space` returns HTTP 200
- [x] T039 [US3] Verify Homepage auto-discovery: labels present, service visible via docker socket proxy
- [x] T040 [US3] Verify AutoKuma auto-discovery: monitor created for tunnel health
- [ ] T041 [US3] Configure GitHub webhook in Komodo with signature secret from 1Password and verify webhook delivery through tunnel
- [ ] T042 [US3] Verify end-to-end: push to GitHub repo triggers webhook → Cloudflare edge → tunnel → Caddy → Komodo → stack redeploy

**Checkpoint**: Cloudflare Tunnel operational. External GitHub webhooks reach Komodo through tunnel without WAN port exposure. Tunnel auto-discovered in Homepage and Uptime Kuma.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that enhance the overall label-driven infrastructure

- [x] T043 [P] Update `docs/deployment/OBSERVABILITY_COMPLETE_LABEL_EXAMPLES.md` with Authentik, monitoring, and tunnel label examples
- [x] T044 [P] Update `stacks/platform/monitoring/README.md` with post-deployment verification steps and known gaps (dashboard provisioning, log shipping, alerting)
- [ ] T045 Verify all deployed services comply with ADR-0034 label requirements by inspecting `deploy.labels` via `docker service inspect` for every service
- [ ] T046 Run `specs/002-label-driven-swarm-infrastructure/quickstart.md` end-to-end validation: deploy a test service using the quickstart template and verify auto-discovery in Homepage, Caddy, and AutoKuma within 60 seconds

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verify existing infrastructure
- **Foundational (Phase 2)**: Depends on Setup — creates 1Password items
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (P1 → P2 → P3)
  - US1 and US2 are independent (can run in parallel if staffed)
  - US3 is independent of US1/US2
- **Polish (Phase 6)**: Depends on all user stories being deployed

### User Story Dependencies

- **US1 (Authentik)**: Depends on Phase 2 (T005 — 1Password item). Independent of US2/US3.
- **US2 (Monitoring)**: Depends on Phase 2 (T006 — 1Password item). Independent of US1/US3.
- **US3 (Cloudflare Tunnel)**: Depends on Phase 2 (T007, T008 — 1Password item + tunnel creation). Independent of US1/US2.

### Within Each User Story

- Verify compose file → Run validation script → Deploy via Komodo → Verify auto-discovery → Post-deployment tasks
- Each story is a complete, independently deployable increment

### Parallel Opportunities

- **Phase 2**: T005, T006, T007, T008 can all run in parallel (different 1Password items)
- **US1**: T009-T012 are verification tasks that can run in parallel
- **US2**: T020-T024 are verification tasks that can run in parallel
- **US3**: T033, T034 can run in parallel (different files)
- **Cross-story**: US1, US2, US3 can run in parallel after Phase 2 completion

---

## Parallel Example: User Story 2

```bash
# Verify all compose/config files in parallel:
Task: "Verify monitoring compose labels in stacks/platform/monitoring/compose.yaml"
Task: "Verify op-secrets job mode in stacks/platform/monitoring/compose.yaml"
Task: "Verify Prometheus config in stacks/platform/monitoring/prometheus/prometheus.yml"
Task: "Verify Grafana datasources in stacks/platform/monitoring/grafana/provisioning/datasources/datasources.yaml"
Task: "Verify Loki config in stacks/platform/monitoring/loki/loki-config.yaml"

# Then sequentially:
Task: "Run validation script"
Task: "Deploy via Komodo"
Task: "Verify auto-discovery"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Verify infrastructure
2. Complete Phase 2: Create 1Password items (only T005 needed for MVP)
3. Complete Phase 3: Deploy Authentik
4. **STOP and VALIDATE**: Verify SSO is operational, auto-discovered, forward auth pattern works
5. This delivers SSO capability to protect all downstream services

### Incremental Delivery

1. Phase 1 + Phase 2 → Foundation ready
2. US1 (Authentik) → SSO for all services (MVP!)
3. US2 (Monitoring) → Metrics, logs, dashboards
4. US3 (Cloudflare Tunnel) → External webhook access
5. Each story adds independent value without breaking previous stories

### Priority Rationale

- **US1 (Authentik)** is P1 because SSO is a prerequisite for securing all other services
- **US2 (Monitoring)** is P2 because observability is needed for operational maturity
- **US3 (Cloudflare Tunnel)** is P3 because external webhooks are a convenience, not a blocker

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently deployable and verifiable via Komodo
- Validation scripts serve as the testing mechanism (no unit/integration test framework)
- All deployments go through Komodo UI (ADR-0022), not direct `docker stack deploy`
- Labels MUST be under `deploy.labels` (ADR-0034), never container `labels`
- Secrets MUST use one-shot `replicated-job` hydration (ADR-0035)
- Stop at any checkpoint to validate story independently
