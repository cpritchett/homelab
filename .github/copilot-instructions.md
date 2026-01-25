# GitHub Copilot Instructions (Router)

This file contains **Copilot-specific tool guidance only**. All governance, procedures, and operating rules are in canonical sources.

## Canonical Authority (Copilot MUST read first)

Read in this order; later sources do not override earlier ones:

1. **`constitution/constitution.md`** — Immutable principles
2. **`constitution/amendments/`** — Amendment procedures and processes
3. **`contracts/agents.md`** — Agent operating rules and constraints
4. **`contracts/hard-stops.md`** — Actions requiring human approval
5. **`contracts/invariants.md`** — System invariants (what must always be true)
6. **`requirements/workflow/spec.md`** — Agent governance steering and workflows
7. **`requirements/**/spec.md`** — Domain specifications
8. **`docs/adr/`** — Architectural decision rationale
9. **`docs/governance/procedures.md`** — Procedural workflows

## Copilot-Specific Guidance

### CI Gate Execution
Before completing any change, run locally:
```bash
./scripts/run-all-gates.sh "PR title with ADR reference" "PR description"
```
All gates must pass. Review the validation output and include evidence in PR description.

### VS Code Tool Calls
When making tool calls:
- Use standard VS Code API documentation
- Prefer symbolic editing tools (Serena MCP) for code changes
- Organize edits: read context in parallel, apply changes in order
- Batch independent edits with `multi_replace_string_in_file` for efficiency

### Security Scanning
Before finalizing changes, run:
```bash
gitleaks detect --source . --verbose --config .gitleaks.toml
```
Commit hooks run `gitleaks protect --staged --redact`.

### Common Commands for This Repo
```bash
# Install tools (required first time)
mise install

# Run all CI gates
./scripts/run-all-gates.sh "PR title" "PR body"

# Security scan
mise run security:scan:repo
