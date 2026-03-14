# ADR-0040: Repo-Local Codex Skills

**Status**: Accepted
**Date**: 2026-03-07
**Deciders**: cpritchett (repo owner)

---

## Context

ADR-0025 established a strict markdown allowlist to prevent arbitrary documentation sprawl. That policy did not reserve a path for repo-local Codex skills, which require a checked-in `SKILL.md` file under a predictable skill directory.

Symlink-based workarounds are not acceptable in this repository because some tooling does not handle them reliably. Repo-local skills therefore need a first-class, non-symlink location that remains narrow enough to preserve the intent of ADR-0025.

---

## Decision

Allow repo-local Codex skills under `.codex/skills/` with a constrained markdown footprint:

- `.codex/skills/<skill-name>/SKILL.md`
- `.codex/skills/<skill-name>/references/*.md`

No other markdown paths under `.codex/skills/` are permitted by default.

Repo-local Codex skills are allowed only for tool-specific procedural guidance and reusable references. They must not replace canonical governance, must not duplicate constitutional or contract rules, and must continue to reference canonical sources for governance decisions.

---

## Rationale

1. Codex skills are operational artifacts, not arbitrary notes.
2. A narrow allowlist preserves the anti-sprawl intent of ADR-0025.
3. Real files are more portable than symlinks in this repository's tooling.
4. Keeping the location predictable allows CI enforcement to stay simple.

---

## Consequences

### Allowed

- Checking in repo-local Codex skills for repeatable workflows
- Keeping skill-specific reference docs next to the skill

### Not allowed

- Arbitrary markdown under `.codex/`
- Role-specific instruction grab bags outside approved governance and skill locations
- Copying governance rules into skills instead of linking to canonical sources

---

## Implementation

Update:

1. `scripts/enforce-markdown-allowlist.sh`
2. `scripts/check-no-agent-grab-bag.sh`
3. `contracts/invariants.md`
4. `requirements/workflow/spec.md`
5. `requirements/workflow/checks.md`
6. `.codex/skills/*/SKILL.md` (initial skill content)

---

## Related

- [ADR-0025: Strict Markdown Governance & Artifact Location](./ADR-0025-strict-markdown-governance.md)
- [ADR-0030: Agent Governance Steering Pattern](./ADR-0030-agent-governance-steering.md)
- [Workflow spec](../../requirements/workflow/spec.md)
