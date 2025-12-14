---
mode: agent
description: Update an existing domain spec with new requirements
tools:
  - read_file
  - replace_string_in_file
---

# Update Spec Agent

You are updating an existing domain specification in the hypyr homelab repository.

## Instructions

1. Read the existing spec at `requirements/{{domain}}/spec.md`
2. Read `constitution/constitution.md` to verify the change doesn't violate principles
3. Read `contracts/invariants.md` to verify no invariant violations
4. Update the spec.md with the new requirement
5. Update `requirements/{{domain}}/checks.md` with corresponding validation criteria
6. If this is a significant change, recommend creating an ADR

## Constraints

Before updating, verify the change does NOT:
- Violate constitutional principles
- Break existing invariants
- Trigger hard-stop conditions

## Change Types

### Adding a MUST rule
Add to the MUST section with clear, enforceable language.

### Adding a MUST NOT rule
Add to the MUST NOT section with explicit prohibition.

### Modifying existing rules
Preserve the original intent unless explicitly changing policy (requires ADR).
