## Summary
<!-- Describe what this change does -->

<!-- REQUIRED FOR CANONICAL CHANGES: If this PR modifies constitution/, contracts/, or requirements/,
     you MUST include an ADR reference below. The CI gate searches for pattern: ADR-[0-9]{4} -->

**ADR Reference:** <!-- e.g., ADR-0032 (required if canonical paths changed) -->

**Commit message (if single change):**
```
<type>(<scope>): <subject>
```

## Change Classification
<!-- Check ONE. This determines gate requirements. -->
- [ ] **Doc-only** — Only changes `docs/` (no ADR required)
- [ ] **Non-canonical** — Changes `infra/`, `ops/`, `scripts/`, `stacks/` (ADR recommended for arch changes)
- [ ] **Canonical** — Changes `constitution/`, `contracts/`, or `requirements/` (ADR REQUIRED)
- [ ] **Constitutional** — Changes `constitution/constitution.md` (human approval + ADR required)

## Specs impact
- [ ] Updates `requirements/` (domain specs) → ADR required
- [ ] Updates `contracts/` (agent rules or invariants) → ADR required
- [ ] Adds/updates ADR(s) under `docs/adr/`
- [ ] Docs-only change

## Constitution check
- [ ] This does not violate `constitution/constitution.md`
- [ ] This does not violate `contracts/invariants.md`
- [ ] This does not trigger any `contracts/hard-stops.md` conditions
- [ ] If it changes a rule, the relevant spec is updated and an ADR is added

## Risks
- [ ] Risk register updated (if applicable)

## Approval
- [ ] All changed ADRs and constitutional amendments have `**Status:** Accepted` (no `Proposed` statuses)
- [ ] Explicit human approval has been granted for governance documents (ADR/amendments)
- [ ] PR title/body includes ADR reference for canonical changes (format: `ADR-NNNN`)
