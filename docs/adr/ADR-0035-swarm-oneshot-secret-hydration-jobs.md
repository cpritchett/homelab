# ADR-0035: Swarm One-Shot Secret Hydration Uses Job Mode

**Status:** Accepted
**Date:** 2026-02-09
**Authors:** Platform Engineering
**Supersedes:** None
**Relates to:** ADR-0032 (1Password Connect Swarm), ADR-0022 (Komodo-managed stacks)

## Context

Docker Swarm stacks in this repository use 1Password Connect and `op inject` to hydrate runtime secret files for services.

Historically, hydration services were implemented as normal replicated services, which created two operational problems:
1. One-shot completion showed as `0/1` and could be interpreted as stack failure by operators.
2. Teams could keep hydration containers running indefinitely to force green `1/1`, wasting resources and obscuring the intended one-shot behavior.

A consistent, enforceable pattern is needed so one-shot hydration semantics are explicit and auditable.

## Decision

For Docker Swarm stacks using `op inject` one-shot hydration:

1. Hydration services MUST use Swarm job mode:
   - `deploy.mode: replicated-job`
   - `deploy.restart_policy.condition: none`
2. Successful completion state is `0/1 (1/1 completed)`.
3. Long-running replicated hydration services used only to force `1/1` are prohibited.
4. If a stack supports fallback to pre-existing hydrated files, fallback behavior MUST be explicit and fail fast when no valid file exists.

## Consequences

### Positive

- One-shot behavior is represented by the orchestrator natively.
- Resource usage is reduced versus always-on injector sidecars.
- Review and CI checks can validate a single canonical pattern.

### Tradeoffs

- Operators and tooling must interpret completed jobs as success (`1/1 completed`) rather than expecting replicated `1/1`.
- Stack health UX may differ across UIs if job semantics are rendered inconsistently.

## Implementation

Canonical requirement is codified in:
- `requirements/secrets/spec.md`
- `requirements/secrets/checks.md`

Governance/procedure docs may reference this rule but do not define authority.
