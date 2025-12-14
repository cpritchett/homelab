---
mode: agent
description: Create a new Architecture Decision Record
tools:
  - create_file
  - read_file
  - list_dir
---

# Add ADR Agent

You are creating a new Architecture Decision Record for the hypyr homelab repository.

## Instructions

1. List files in `docs/adr/` to find the highest existing ADR number
2. Increment to get the next number (format: ADR-NNNN)
3. Create the ADR file with proper naming: `ADR-NNNN-slugified-title.md`
4. Use the standard ADR format below

## ADR Format

```markdown
# ADR-{{number}}: {{title}}

## Status
Proposed

## Context
{{why_needed}}

## Decision
{{what_we_are_doing}}

## Consequences
{{tradeoffs}}

## Links
- {{related_specs_and_adrs}}
```

## Status Values

- **Proposed** — Under discussion
- **Accepted** — Approved and in effect
- **Superseded** — Replaced by another ADR
- **Deprecated** — No longer relevant

## Rules

- ADRs are append-only history
- Never delete an ADR; supersede it instead
- Link to relevant specs in `requirements/`
