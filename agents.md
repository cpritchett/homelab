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

## PR Body Requirements for CI Gates

**CRITICAL:** The `require_adr_for_canonical_changes` gate will FAIL if:
- You modify files in `constitution/`, `contracts/`, or `requirements/`
- AND the PR title or body does NOT contain an ADR reference matching `ADR-[0-9]{4}`

### Required PR Body Format for Canonical Changes

When creating or updating a PR that touches canonical paths, ALWAYS include:

```markdown
**ADR Reference:** ADR-NNNN (description)
```

Example:
```markdown
**ADR Reference:** ADR-0032 (1Password Connect for Docker Swarm Secrets)
```

The gate searches PR title + body for the regex pattern `ADR-[0-9]{4}`. Without this, canonical PRs will be blocked.

## Definition of Done
Before completing any change, you MUST:
1. **Classify change:** doc-only | non-canonical | canonical | constitutional
2. **Determine ADR requirement:**
   - Canonical changes (`constitution/`, `contracts/`, `requirements/`) → ADR REQUIRED
   - Non-canonical changes → ADR recommended for architectural decisions
   - Doc-only changes → No ADR required
3. **Create ADR** (if required): next sequential number in `docs/adr/`
4. **Link ADR from spec** (if canonical): add to `requirements/<domain>/spec.md`
5. **Include ADR in PR:** Add `ADR-NNNN` reference in PR title or body
6. **Run all gates:** `./scripts/run-all-gates.sh "PR title with ADR-NNNN" "PR body with ADR-NNNN"`
7. **Provide evidence:** document gate results and classification in PR

## Quick Commands
```bash
# Run all CI gates locally (include ADR reference in title for canonical changes)
./scripts/run-all-gates.sh "feat: add feature (ADR-0032)" "Implements ADR-0032"

# Run individual gates
./scripts/no-invariant-drift.sh
./scripts/require-adr-on-canonical-changes.sh
./scripts/adr-must-be-linked-from-spec.sh

# Check for secrets
gitleaks detect --source . --verbose
```

## Change Rubric
| Change Type | Paths | ADR Required | Gate |
|-------------|-------|--------------|------|
| **Canonical** | `constitution/`, `contracts/`, `requirements/` | YES | `require_adr_for_canonical_changes` |
| **Non-canonical** | `infra/`, `ops/`, `scripts/`, `stacks/` | Recommended | None |
| **Doc-only** | `docs/` only | No | None |

See `docs/governance/procedures.md` for complete rubric.

## GitOps Validation
See `contracts/invariants.md` § GitOps Invariants for:
- HelmRelease render checks
- Kustomization build validation
- Cross-environment leakage prevention
- CRD ordering requirements
- Talos ytt rendering rules

