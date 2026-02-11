# Implementation Plan: Label-Driven Docker Swarm Infrastructure

**Branch**: `002-label-driven-swarm-infrastructure` | **Date**: 2026-02-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-label-driven-swarm-infrastructure/spec.md`

## Summary

Migrate from Kubernetes-style infrastructure to Docker Swarm with a label-driven service discovery pattern. All service metadata (ingress, monitoring, dashboards) is declared once in `deploy.labels` sections of Docker Compose files, replacing manual configuration with declarative labels consumed by Caddy (reverse proxy), Homepage (dashboard), and AutoKuma (uptime monitoring). Governance is enforced via ADR-0034 (label requirement) and ADR-0022 (Komodo deployment requirement).

## Technical Context

**Language/Version**: POSIX shell (`#!/bin/sh`) for scripts; YAML for Docker Compose and configuration files
**Primary Dependencies**: Docker Swarm (orchestration), Caddy + caddy-docker-proxy (ingress), Homepage (dashboard), AutoKuma 2.0.0 (monitoring bridge), Uptime Kuma (monitoring), Komodo (stack deployment), 1Password Connect (secrets)
**Storage**: TrueNAS host paths — `/mnt/apps01/appdata/` (application state), `/mnt/data01/appdata/` (persistent data); Docker overlay networks for service communication
**Testing**: Pre-deployment validation scripts (`scripts/validate-*.sh`), idempotent, POSIX-compatible, < 10s execution
**Target Platform**: Docker Swarm on TrueNAS (Linux/amd64)
**Project Type**: Infrastructure-as-Code (Docker Compose stacks + shell scripts)
**Performance Goals**: Service auto-discovery latency < 60 seconds; new service deployment < 5 minutes
**Constraints**: All secrets via 1Password Connect (no plaintext on disk); Komodo-managed deployment (no direct `docker stack deploy` for platform/app tier); labels under `deploy.labels` (not container `labels`)
**Scale/Scope**: ~10-15 Docker Swarm services across 3 tiers (infrastructure, platform, application)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle Compliance

| Principle | Status | Notes |
|-----------|--------|-------|
| 1. Management is Sacred and Boring | PASS | No changes to management network; Swarm runs on TrueNAS, not management VLAN |
| 2. DNS Encodes Intent | PASS | Internal services use `*.in.hypyr.space`; public services use `*.hypyr.space` via Cloudflare |
| 3. External Access is Identity-Gated | PASS | External access via Caddy with Cloudflare DNS-01 TLS; no WAN port exposure |
| 4. Routing Does Not Imply Permission | PASS | Network segmentation via overlay networks; `proxy_network` for public, internal overlays for private |
| 5. Prefer Structural Safety Over Convention | PASS | Label-driven pattern enforces structure; governance via ADR-0034/0022 |

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
| Repository: NAS stacks Komodo-managed | PASS | Platform/app tier deployed via Komodo UI (ADR-0022) |
| Repository: Markdown on allowlist | PASS | All docs in permitted `specs/002-*/` paths |
| Repository: Deployment targets separated | PASS | All Swarm stacks under `stacks/` directory |

**GATE RESULT: PASS** — No violations. Proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/002-label-driven-swarm-infrastructure/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
stacks/
├── infrastructure/                     # Tier 1: Bootstrap (script-deployed)
│   ├── caddy-compose.yaml             # Caddy reverse proxy + TLS
│   ├── komodo-compose.yaml            # Komodo orchestration
│   └── op-connect-compose.yaml        # 1Password Connect secrets
├── platform/                           # Tier 2: Komodo-deployed
│   ├── observability/                 # Homepage + Uptime Kuma + AutoKuma
│   │   ├── compose.yaml
│   │   └── homepage/config/
│   ├── monitoring/                    # Prometheus + Grafana + Loki
│   │   ├── compose.yaml
│   │   ├── prometheus/prometheus.yml
│   │   ├── grafana/provisioning/
│   │   └── loki/loki-config.yaml
│   └── auth/authentik/                # Authentik SSO (prepared)
│       └── compose.yaml
└── docs/                              # Stack documentation

scripts/
├── truenas-init-bootstrap.sh          # Infrastructure bootstrap
├── validate-authentik-setup.sh        # Authentik pre-deployment
├── validate-monitoring-setup.sh       # Monitoring pre-deployment
└── create-swarm-secrets.sh            # Swarm secret creation

docs/
├── adr/ADR-0034-label-driven-infrastructure.md
├── adr/ADR-0022-truenas-komodo-stacks.md
├── adr/ADR-0035-swarm-one-shot-secret-hydration.md
├── governance/SERVICE_DEPLOYMENT_CHECKLIST.md
└── governance/PRE-DEPLOYMENT-VALIDATION-POLICY.md
```

**Structure Decision**: Infrastructure-as-Code layout using `stacks/` for Docker Compose definitions, `scripts/` for validation/bootstrap, and `docs/` for governance. No `src/` directories — this is a declarative infrastructure project, not an application.

## Complexity Tracking

> No constitution violations detected. No complexity justifications required.
