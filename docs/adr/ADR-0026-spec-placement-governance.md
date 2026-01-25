# ADR-0026: Spec Placement Governance
**Status:** Accepted  \
**Date:** 2026-01-25  \
**Deciders:** cpritchett (repo owner)  \
**See also:** ADR-0024 (speckit workflow), ADR-0025 (markdown governance)

## Context
- Spec documents existed in three locations: `requirements/**/spec.md` (canonical), `kubernetes/clusters/homelab/**/spec.md`, and `bootstrap/spec.md` / `talos/spec.md`. This violated repository structure expectations and was invisible to CI.
- Specify agents default to writing into `specs/`, but ADRs did not allow `specs/` as a spec location, causing drift and agent confusion.
- We need a single, enforced rule for canonical vs non-canonical specs, with CI guardrails and agent defaults aligned.

## Decision
- **Canonical specs** remain in `requirements/<domain>/spec.md` (one per domain).
- **Non-canonical/operational specs** live in `specs/NNN-<slug>/spec.md` (with optional plan/research/data-model/quickstart/checklists/tasks).
- **Disallow** `spec.md` anywhere else (e.g., `kubernetes/`, `bootstrap/`, `talos/`).
- **Migrated** existing non-canonical specs into `specs/`:
  - `bootstrap/spec.md` → `specs/002-bootstrap/spec.md`
  - `kubernetes/clusters/homelab/apps/spec.md` → `specs/003-k8s-apps/spec.md`
  - `kubernetes/clusters/homelab/flux/spec.md` → `specs/004-k8s-flux/spec.md`
  - `kubernetes/clusters/homelab/platform/spec.md` → `specs/005-k8s-platform/spec.md`
  - `talos/spec.md` → `specs/006-talos/spec.md`
- **CI gate:** add `scripts/check-spec-placement.sh` and wire into `scripts/run-all-gates.sh` to fail if any `spec.md` is outside `requirements/` or `specs/`.
- **Agent default:** speckit/specify agents target `specs/` for non-canonical work; canonical changes must be explicit and reviewed.

## Consequences
- CI now blocks misplaced specs; future spec additions must follow the canonical/non-canonical split.
- Agents have a safe default location (`specs/`), reducing accidental governance violations.
- References updated to the new `specs/NNN-*` locations for moved non-canonical specs.
- Governance documents (invariants, markdown allowlist) now reflect the enforced placement.
