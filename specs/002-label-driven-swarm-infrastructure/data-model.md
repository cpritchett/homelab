# Data Model: Label-Driven Docker Swarm Infrastructure

**Date**: 2026-02-10
**Spec**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)

## Overview

This feature is infrastructure-as-code — there are no traditional database entities. The "data model" consists of Docker Swarm service definitions, label schemas, network topology, and secret hydration patterns. This document defines the structural contracts for these entities.

---

## Entity: Swarm Service

A Docker Swarm service is the fundamental deployment unit. Every service MUST declare metadata via `deploy.labels`.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image` | string | YES | Container image with SHA-256 digest pin |
| `deploy.mode` | enum | NO | `replicated` (default) or `replicated-job` |
| `deploy.replicas` | integer | NO | Number of task replicas (default: 1) |
| `deploy.restart_policy.condition` | enum | NO | `on-failure` (services) or `none` (jobs) |
| `deploy.resources.limits.cpus` | string | YES | CPU limit (e.g., `'2'`) |
| `deploy.resources.limits.memory` | string | YES | Memory limit (e.g., `2048M`) |
| `deploy.resources.reservations.cpus` | string | NO | CPU reservation |
| `deploy.resources.reservations.memory` | string | NO | Memory reservation |
| `deploy.labels` | map | YES | Service-level labels (see Label Schema) |
| `networks` | list | YES | Network attachments |
| `secrets` | list | NO | Swarm secret references |
| `volumes` | list | NO | Volume mounts |

### Validation Rules

- Image MUST include `@sha256:` digest for reproducibility
- Resource limits MUST be set for all services
- Labels MUST be under `deploy.labels`, NOT container-level `labels`
- At least one network MUST be specified

---

## Entity: Label Schema

Three label families are consumed by infrastructure services. All are declared under `deploy.labels`.

### Homepage Labels

| Label | Type | Required | Description |
|-------|------|----------|-------------|
| `homepage.group` | string | YES | Dashboard group name |
| `homepage.name` | string | YES | Display name |
| `homepage.icon` | string | YES | Icon filename (e.g., `grafana.png`) |
| `homepage.href` | URL | YES | Link to service |
| `homepage.description` | string | YES | Brief description |
| `homepage.widget.type` | string | NO | Widget type (e.g., `prometheus`, `grafana`, `customapi`) |
| `homepage.widget.url` | URL | NO | Widget data endpoint |
| `homepage.widget.*` | varies | NO | Widget-specific fields |

### Caddy Labels

| Label | Type | Required | Description |
|-------|------|----------|-------------|
| `caddy` | string | YES (if public) | FQDN (e.g., `grafana.in.hypyr.space`) |
| `caddy.reverse_proxy` | string | YES (if public) | Upstream (e.g., `{{upstreams 3000}}`) |
| `caddy.tls.dns` | string | YES (if public) | TLS provider (e.g., `cloudflare {env.CLOUDFLARE_API_TOKEN}`) |
| `caddy.forward_auth` | string | NO | Authentik forward auth endpoint |
| `caddy.forward_auth.uri` | string | NO | Auth check URI |
| `caddy.forward_auth.copy_headers` | string | NO | Headers to copy from auth response |

### AutoKuma Labels

| Label | Type | Required | Description |
|-------|------|----------|-------------|
| `kuma.<id>.http.name` | string | YES | Monitor display name |
| `kuma.<id>.http.url` | URL | YES | Health check URL |
| `kuma.<id>.http.interval` | string | YES | Check interval in seconds |
| `kuma.<id>.http.maxretries` | string | YES | Max retry count |
| `kuma.<id>.http.accepted_statuscodes` | string | NO | Accepted HTTP codes (e.g., `[200]`) |
| `kuma.<id>.http.keyword` | string | NO | Expected keyword in response |
| `kuma.<id>.keyword.name` | string | NO | Keyword monitor name |
| `kuma.<id>.keyword.url` | URL | NO | Keyword check URL |
| `kuma.<id>.keyword.keyword` | string | NO | Expected keyword |

### Validation Rules

- `<id>` in AutoKuma labels must be unique per service
- Homepage labels are REQUIRED for all services (ADR-0034)
- Caddy labels are REQUIRED for publicly accessible services (ADR-0034)
- AutoKuma labels are REQUIRED for all services (ADR-0034)
- All labels MUST be under `deploy.labels` (not container `labels`)

---

## Entity: Network

Docker overlay networks provide service isolation and communication paths.

### Defined Networks

| Network | Type | Scope | Used By |
|---------|------|-------|---------|
| `proxy_network` | external overlay | Cross-stack | All publicly accessible services + Caddy |
| `op-connect_op-connect` | external overlay | Cross-stack | Secret hydration jobs + 1Password Connect |
| `monitoring` | stack overlay | Stack-internal | Prometheus, Grafana, Loki |
| `authentik` | stack overlay | Stack-internal | Authentik server, worker, PostgreSQL, Redis |
| `observability` | stack overlay | Stack-internal | Homepage, Uptime Kuma, AutoKuma |

### Validation Rules

- Services requiring Caddy ingress MUST attach to `proxy_network`
- Secret hydration jobs MUST attach to `op-connect_op-connect`
- Internal databases (PostgreSQL, Redis) MUST NOT attach to `proxy_network`
- Stack-internal overlays SHOULD use `internal: true` where possible

---

## Entity: Secret Hydration Job

One-shot jobs that inject secrets from 1Password into shared volumes.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deploy.mode` | const | YES | Must be `replicated-job` |
| `deploy.restart_policy.condition` | const | YES | Must be `none` |
| `image` | const | YES | `1password/op:2@sha256:<digest>` |
| `environment.OP_CONNECT_HOST` | URL | YES | `http://op-connect-api:8080` |
| `environment.OP_CONNECT_TOKEN_FILE` | path | YES | `/run/secrets/op_connect_token` |
| `secrets` | list | YES | Must include `op_connect_token` |
| `volumes` | list | YES | Template input (ro) + secrets output |
| `networks` | list | YES | Must include `op-connect` network |

### State Transitions

```
PENDING → RUNNING → COMPLETED (success: 0/1 (1/1 completed))
PENDING → RUNNING → FAILED (error: secrets injection failed)
```

### Template Format

Templates use `op://vault/item/field` references:
```
VARIABLE_NAME=op://homelab/item-name/field-name
```

### Validation Rules

- Job MUST complete before dependent services start
- Template files MUST be mounted read-only
- Output directory MUST have correct UID/GID permissions
- Failed hydration MUST cause stack deployment failure (fail-fast)

---

## Entity: Validation Script

Pre-deployment scripts that verify prerequisites before stack deployment.

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Shebang | const | YES | `#!/bin/sh` (POSIX, not bash) |
| Exit code | integer | YES | 0 = success, non-zero = failure |
| Execution time | duration | YES | Must complete in < 10 seconds |
| Idempotency | boolean | YES | Must be safe to run multiple times |

### Checks Performed

| Check | Method | Failure Action |
|-------|--------|---------------|
| Docker running | `docker info` | Exit 1 |
| Swarm mode active | `docker info --format '{{.Swarm.LocalNodeState}}'` | Exit 1 |
| op-connect running | `docker service ls \| grep op-connect` | Exit 1 |
| Required networks | `docker network inspect <name>` | Exit 1 |
| Required secrets | `docker secret inspect <name>` | Exit 1 |
| Directory structure | `mkdir -p` + `chown` | Create/fix |
| 1Password connectivity | `curl http://op-connect-api:8080/health` | Exit 1 |

---

## Entity: Stack Tier

Services are organized into deployment tiers with dependency ordering.

### Tier Definitions

| Tier | Deployment Method | Services | Dependencies |
|------|-------------------|----------|-------------|
| Infrastructure | Bootstrap script (`truenas-init-bootstrap.sh`) | op-connect, Komodo, Caddy | None (first deployed) |
| Platform | Komodo UI | Observability, Monitoring, Auth, CI/CD | Infrastructure tier |
| Application | Komodo UI | User-facing services | Platform + Infrastructure tier |

### State Transitions

```
Infrastructure (bootstrap) → Platform (Komodo) → Application (Komodo)
```

### Validation Rules

- Infrastructure tier services MUST be deployable without Komodo
- Platform/Application tier MUST deploy via Komodo (ADR-0022)
- Each tier MUST have validation scripts for its prerequisites
- Cross-tier dependencies MUST use external overlay networks

---

## Relationships

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Secret       │────▶│ Swarm        │────▶│ Label        │
│ Hydration    │     │ Service      │     │ Schema       │
│ Job          │     │              │     │              │
└──────────────┘     └──────┬───────┘     └──────────────┘
                            │
                     ┌──────┴───────┐
                     │              │
              ┌──────▼──────┐ ┌────▼─────────┐
              │ Network     │ │ Validation   │
              │             │ │ Script       │
              └─────────────┘ └──────────────┘
```

- Secret Hydration Job **produces** environment files consumed by Swarm Services
- Swarm Services **declare** Label Schema entries consumed by Caddy/Homepage/AutoKuma
- Swarm Services **attach to** Networks for communication
- Validation Scripts **verify** prerequisites for Swarm Service deployment
- Stack Tiers **order** deployment of Swarm Services
