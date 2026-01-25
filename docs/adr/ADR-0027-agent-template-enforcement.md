# ADR-0027: Agent PR/Issue Template Enforcement (supersedes ADR-0005)
**Status:** Accepted  \
**Date:** 2026-01-25  \
**Deciders:** cpritchett (repo owner)  \
**Supersedes:** ADR-0005  \
**See also:** ADR-0005 (agent governance procedures)

## Context
ADR-0005 established comprehensive agent governance procedures including CI gates, change classification, and the agent contract. However, it did not enforce a standardized format for agent-created PRs and issues.

Observed problems:
- Agents create PRs with inconsistent descriptions (missing Constitution check, Specs impact, Risks sections)
- Policy change issues lack required structure (no invariant reference, ADR ID, rollback plan)
- PR descriptions don't follow `.github/PULL_REQUEST_TEMPLATE.md` format
- Difficult to validate compliance when format varies

The repository already has templates:
- `.github/PULL_REQUEST_TEMPLATE.md` - Standard PR format with Constitution check, Specs impact, Risks
- `.github/ISSUE_TEMPLATE/policy-change.yml` - Structured policy change proposals

But agents were not explicitly required to use them, leading to format drift and incomplete compliance documentation.

## Decision
**Supersede ADR-0005** and strengthen agent governance by mandating template usage.

### Required Workflows (added to contracts/agents.md)
Agents MUST:
- Use `.github/PULL_REQUEST_TEMPLATE.md` format when creating/updating PR descriptions
- Use `.github/ISSUE_TEMPLATE/policy-change.yml` structure when proposing governance changes
- Fill all required checklist items in templates (do not skip or leave incomplete)
- Provide evidence of CI gate passage in PR descriptions

### Prohibited Actions (added to contracts/agents.md)
Agents MUST NOT:
- Create PRs or issues without following repository templates

### Updated Documentation
- **contracts/agents.md**: Added "Required workflows" section and template prohibition
- **.github/copilot-instructions.md**: Added "PR and Issue Templates" section with explicit references

### Enforcement
- No automated gate (templates are GitHub UI features, not file-based)
- Human review during PR approval
- Agent instructions explicitly state the requirement

## Consequences

### Positive
1. **Consistent PR format** - All agent-created PRs follow standard checklist structure
2. **Complete compliance documentation** - Constitution check, Specs impact, Risks always present
3. **Easier review** - Reviewers know where to find key information
4. **Policy change clarity** - Structured issue format ensures required fields (ADR ID, invariant, rollback plan)
5. **Builds on ADR-0005** - Extends existing agent governance without replacing it

### Negative / Tradeoffs
1. **No automated enforcement** - Relies on human review and agent compliance
2. **Slightly more verbose** - Template structure adds boilerplate (but improves clarity)
3. **Learning curve** - Agents must learn template structure

Mitigations:
- Templates are visible in `.github/` directory for easy reference
- Agent instructions explicitly list template locations
- Standard format reduces ambiguity (less back-and-forth in reviews)

## Alternatives Considered

### Alternative 1: Create automated gate for template validation
Parse PR descriptions and validate against template structure

**Rejected because:**
- GitHub PR descriptions are not file-based (API-only access)
- Complex parsing logic required
- Template format may evolve (gate would need updates)
- Human review already validates this

### Alternative 2: Amend ADR-0005 instead of superseding
Add template requirement as addendum to ADR-0005

**Rejected because:**
- Superseding makes the evolution clear (ADR-0005 → ADR-0027)
- Template enforcement is a distinct decision from original governance procedures
- Superseding allows ADR-0005 to remain append-only while documenting the enhancement

### Alternative 3: Don't enforce, just recommend
Make template usage optional/recommended

**Rejected because:**
- Inconsistent format makes compliance validation harder
- Optional requirements lead to format drift
- Templates already exist; enforcement costs nothing

## References
- ADR-0005: [Agent Governance Procedures](ADR-0005-agent-governance-procedures.md) (superseded)
- PR Template: [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md)
- Issue Template: [.github/ISSUE_TEMPLATE/policy-change.yml](../../.github/ISSUE_TEMPLATE/policy-change.yml)
- Agent Rules: [contracts/agents.md](../../contracts/agents.md)
- Copilot Instructions: [.github/copilot-instructions.md](../../.github/copilot-instructions.md)
