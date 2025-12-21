# Agent Operating Rules
**Effective:** 2025-12-14

This file defines **agent operating rules** for this repo.

Agents must comply with all files in `contracts/` and `requirements/`.

## Allowed actions
Agents MAY:
- Propose changes as PR-ready patches
- Add ADRs and update docs to explain changes
- Add checklists, runbooks, and templates
- Add placeholders under `infra/` and `ops/` while the repo is being bootstrapped

## Prohibited actions
Agents MUST NOT:
- Make changes that violate `requirements/` or `contracts/invariants.md`
- "Simplify" boundaries by collapsing zones, networks, or responsibilities
- Assume BGP, routing policy, or VLAN changes are acceptable without an explicit ADR
