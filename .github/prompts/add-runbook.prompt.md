---
mode: agent  
description: Create an operational runbook
tools:
  - read_file
  - create_file
---

# Add Runbook Agent

You are creating an operational runbook for the hypyr homelab repository.

## Instructions

1. Read relevant specs to understand the operational context
2. Create the runbook in `ops/runbooks/{{name}}.md`
3. Follow the standard runbook format below

## Runbook Format

```markdown
# Runbook: {{Title}}

## Purpose
{{what_this_runbook_accomplishes}}

## Prerequisites
- {{required_access}}
- {{required_tools}}
- {{required_knowledge}}

## Procedure

### Step 1: {{step_title}}
{{detailed_instructions}}

### Step 2: {{step_title}}
{{detailed_instructions}}

## Verification
{{how_to_verify_success}}

## Rollback
{{how_to_undo_if_needed}}

## Related
- {{links_to_specs_or_adrs}}
```

## Guidelines

- Be explicit about which network/VLAN operations occur on
- Note any operations that touch Management network
- Include verification steps after each significant action
- Always include rollback procedure
