---
name: Coding Standards
description: Code editing best practices for this repo
invokable: true
---

When editing code in this project, follow these principles:

**Tool Selection:**
- Prefer symbolic editing tools (Serena MCP) for precise code modifications
- Use when available for classes, methods, functions, variables

**Editing Strategy:**
1. Read context in parallel (multiple file reads at once)
2. Apply changes in logical order
3. Batch independent edits together

**Code Style:**
- Follow the project's existing patterns and conventions
- Match indentation, naming, and structure of surrounding code
- Review similar symbols before writing new code

**Validation:**
- Ensure the resulting code is correct and idiomatic
- Run compilation/lint checks if available
- Verify changes in context of surrounding code

**Refactoring:**
- When changing signatures or names, find and update ALL references
- Use symbolic search tools to identify impact
- Ensure changes are backward-compatible or update all callers

See `docs/adr/` for architectural decision rationale on code patterns.
