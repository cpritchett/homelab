# ADR-0037: Documentation Consolidation

**Status:** Accepted
**Date:** 2026-02-14
**Relates to:** ADR-0033 (TrueNAS Swarm Migration), ADR-0025 (Strict Markdown Governance)

## Context

After the migration from Kubernetes/Talos to Docker Swarm (ADR-0033), significant documentation debt accumulated:

1. **Stale K8s-era docs** — Files referencing Kyverno, VolSync, Talos, and Flux that no longer apply to the current architecture
2. **Scattered runbooks** — Operational procedures split between `ops/runbooks/` and `docs/deployment/`, with no single documentation root
3. **Missing architecture docs** — No centralized reference describing the current Docker Swarm infrastructure, networking, storage, secrets, or deployment flow
4. **Outdated governance** — `repository-structure-policy.md` still listed `bootstrap/`, `kubernetes/`, `talos/`, `infra/`, and `test/` as allowed directories

## Decision

Consolidate all documentation under `docs/` as the single documentation root:

1. **Delete** 7 K8s-legacy docs (Kyverno, VolSync, Talos, outdated PR summary)
2. **Move** runbooks from `ops/runbooks/` to `docs/runbooks/` (6 files, content unchanged)
3. **Create** `docs/architecture/` with 5 architecture documents containing Mermaid diagrams:
   - `overview.md` — tiers, node topology, provisioning pipeline, tech stack
   - `networking.md` — overlay networks, ingress flow, DNS, socket proxy pattern
   - `storage.md` — TrueNAS mounts, per-service storage map, backup, UID/GID
   - `secrets.md` — 1Password Connect, injection pattern, vault map
   - `deployment-flow.md` — Komodo ResourceSync, bootstrap sequence, validation
4. **Update** governance to reflect current directory structure (add `ansible/`, `opentofu/`, `komodo/`; remove decommissioned dirs)
5. **Update** markdown allowlist to remove `ops/runbooks/` pattern

## Consequences

### Positive

- **Single documentation root** — all docs under `docs/`, easy to navigate
- **Architecture onboarding** — new contributors can understand the system from diagrams
- **No stale references** — K8s-era docs removed, governance reflects reality
- **Runbooks co-located** — operational procedures live alongside architecture docs

### Negative

- `ops/` directory retains only `CHANGELOG.md` (reduced purpose)
- Historical ADRs still reference K8s concepts (kept as-is — ADRs are immutable records)

### Neutral

- Markdown allowlist already covered `docs/**/` paths; only `ops/runbooks/` removal was needed
- Existing links in `README.md` and `docs/README.md` updated to new paths
