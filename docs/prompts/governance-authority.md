---
name: Governance Authority
description: Review project governance rules and authorities
invokable: true
---

This project uses a constitution-based governance model. **Read in this order** (later sources do not override earlier ones):

1. **`constitution/constitution.md`** — Immutable principles
2. **`constitution/amendments/`** — Amendment procedures and processes
3. **`contracts/agents.md`** — Agent operating rules and constraints
4. **`contracts/hard-stops.md`** — Actions requiring human approval
5. **`contracts/invariants.md`** — System invariants (what must always be true)
6. **`requirements/workflow/spec.md`** — Agent governance steering and workflows
7. **`requirements/**/spec.md`** — Domain specifications
8. **`docs/adr/`** — Architectural decision rationale
9. **`docs/governance/procedures.md`** — Procedural workflows

**For the current task, determine:**
- Is this a canonical change (constitution/contracts/requirements)?
- Are there hard stops that require human approval?
- What invariants must remain true?
- What ADR documentation is required?

See `docs/governance/` for procedures and governance workflows.
