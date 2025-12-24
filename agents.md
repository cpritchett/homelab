# Agent Operating Rules (Router)

This file is a **non-authoritative entrypoint** for humans and LLM agents.

## Canonical authority (read in this order)
1. `constitution/constitution.md` — immutable principles
2. `contracts/hard-stops.md` — actions requiring human approval
3. `contracts/invariants.md` — must always be true
4. `contracts/agents.md` — what agents may/must not do
5. `requirements/**/spec.md` — domain requirements (DNS/ingress/management/overlay)
6. `requirements/**/checks.md` — validation criteria
7. `docs/adr/*` — historical rationale (append-only)

## Governance procedures (MUST follow)
- **Agent contract:** `docs/governance/agent-contract.md` — strict rules for all agents
- **CI gates:** `docs/governance/ci-gates.md` — required checks before merge
- **Procedures:** `docs/governance/procedures.md` — change workflows

## Rule of conflict
If anything disagrees, **constitution/contracts/requirements win**. Docs are explanatory only.

## Definition of Done
Before completing any change, you MUST:
1. **Classify change:** doc-only | non-canonical | canonical | constitutional
2. **Run all gates:** `./scripts/run-all-gates.sh "PR title" "PR body"`
3. **Create ADR** (if canonical): next sequential number in `docs/adr/`
4. **Link ADR from spec** (if canonical): add to `requirements/<domain>/spec.md`
5. **Provide evidence:** document gate results and classification in PR

## Quick Commands
```bash
# Run all CI gates locally
./scripts/run-all-gates.sh "Your PR title with ADR-NNNN" "PR description"

# Run individual gates
./scripts/no-invariant-drift.sh
./scripts/require-adr-on-canonical-changes.sh
./scripts/adr-must-be-linked-from-spec.sh

# Check for secrets
gitleaks detect --source . --verbose
```

## Change Rubric
- Changing `constitution/`, `contracts/`, `requirements/` → **Canonical** (ADR required)
- Changing `infra/`, `ops/`, scripts → **Non-canonical** (ADR recommended for arch changes)
- Changing `docs/` only → **Doc-only** (ADR not required)
- See `docs/governance/procedures.md` for complete rubric

## GitOps Validation
See `contracts/invariants.md` § GitOps Invariants for:
- HelmRelease render checks
- Kustomization build validation
- Cross-environment leakage prevention
- CRD ordering requirements
- Talos ytt rendering rules

