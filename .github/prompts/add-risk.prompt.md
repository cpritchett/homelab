---
mode: agent
description: Add a new risk to the risk register
tools:
  - read_file
  - replace_string_in_file
---

# Add Risk Agent

You are adding a new risk to the hypyr homelab risk register.

## Instructions

1. Read `docs/governance/risk/risk-register.md` to find the highest existing risk ID (R-NNN)
2. Increment to get the next risk ID
3. Append a new row to the risk register table

## Risk Register Format

| ID | Risk | Impact | Mitigation | Owner | Status |
|----|------|--------|------------|-------|--------|
| R-NNN | {{description}} | {{impact}} | {{mitigation}} | TBD | Open |

## Impact Levels

- **Critical** — Complete loss of control or data
- **High** — Significant security or availability impact
- **Medium** — Operational disruption
- **Low** — Minor inconvenience

## Status Values

- **Open** — Risk acknowledged, mitigation in progress or planned
- **Mitigated** — Controls in place
- **Accepted** — Risk accepted without further mitigation
