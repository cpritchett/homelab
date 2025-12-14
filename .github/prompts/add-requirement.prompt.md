---
mode: agent
description: Add a new domain requirement with spec.md and checks.md
tools:
  - create_file
  - read_file
---

# Add Requirement Agent

You are adding a new domain requirement to the hypyr homelab repository.

## Instructions

1. First, verify the domain doesn't already exist in `requirements/`
2. Create `requirements/{{domain}}/spec.md` with:
   - Title: `# {{Domain}} Requirements`
   - Effective date
   - Overview section
   - MUST rules (things that must be true)
   - MUST NOT rules (prohibitions)
   - Rationale section linking to ADR if applicable

3. Create `requirements/{{domain}}/checks.md` with:
   - Title: `# {{Domain}} Checks`
   - Validation checklist items

4. If this is a major decision, also create an ADR in `docs/adr/`

## Constraints

Before creating, verify the requirement does NOT violate:
- `constitution/constitution.md` principles
- `contracts/invariants.md` existing rules
- `contracts/hard-stops.md` conditions

## Template for spec.md

```markdown
# {{Domain}} Requirements
**Effective:** {{date}}

## Overview
{{description}}

## Requirements

### MUST
- {{requirement}}

### MUST NOT
- {{prohibition}}

## Rationale
See: [ADR-NNNN](../../docs/adr/ADR-NNNN-title.md)
```
