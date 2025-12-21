# GitHub Copilot Instructions (Router)

Keep this file short to prevent drift.

## Canonical sources (read these first)
- Constitution: `constitution/constitution.md`
- Hard-stops: `contracts/hard-stops.md`
- Invariants: `contracts/invariants.md`
- Agent rules: `contracts/agents.md`
- Domain specs: `requirements/**/spec.md`
- Checks: `requirements/**/checks.md`

## Governance procedures (read before making changes)
- Agent contract: `docs/governance/agent-contract.md` - MUST follow strictly
- CI gates: `docs/governance/ci-gates.md` - ALL must pass before completing
- Procedures: `docs/governance/procedures.md` - Required workflows

## Conflict rule
If anything conflicts, the order above wins. `docs/` is explanatory only.

## Before completing any change
1. Run all CI gates locally: `./scripts/run-all-gates.sh "PR title" "PR body"`
2. Create ADR if canonical change (constitution/contracts/requirements/)
3. Link ADR from relevant spec
4. Provide evidence in PR description
