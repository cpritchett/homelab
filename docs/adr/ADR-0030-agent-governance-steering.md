# ADR-0030: Agent Governance Steering Pattern

**Status:** Accepted  
**Date:** 2026-01-25  
**Relates to:** [ADR-0027](./ADR-0027-agent-template-enforcement.md), [ADR-0028](./ADR-0028-constitutional-governance-authority.md), [ADR-0029](./ADR-0029-contract-lifecycle-procedures.md)

## Context

Agent instructions have historically been scattered across role-specific files:
- `CLAUDE.md` — Claude-specific instructions
- `.gemini` — Gemini-specific instructions
- `.github/copilot-instructions.md` — Copilot-specific instructions

This fragmentation creates several problems:

1. **Duplicate governance rules** across multiple files, making governance changes hard to propagate
2. **Agent instruction drift** when governance updates are made to canonical sources but not to agent files
3. **Coupling between agent code and governance documents**, making it hard to update governance without editing agents
4. **Unclear authority**: Is the agent instruction file or the canonical spec the source of truth?

## Decision

We establish a **single source of truth** for agent governance: canonical governance documents.

### Agent Instruction Consolidation

Agent instructions MUST:

1. **Live only in canonical governance documents**:
   - `constitution/constitution.md` — Immutable principles
   - `contracts/agents.md` — Agent operating rules
   - `requirements/workflow/spec.md` § Agent Governance Steering — How agents reference governance
   - Domain specs in `requirements/`
   - `docs/adr/` — Decision rationale
   - `docs/governance/procedures.md` — Procedural workflows

2. **Agents reference governance, not hardcode it**:
   - Each agent file (`*.agent.md`) includes a "## Governance Authority" section
   - This section directs the agent to canonical sources, not to hardcoded rules
   - Agents automatically adapt when governance documents change

3. **Tool-specific guidance is minimal**:
   - `.github/copilot-instructions.md` — Only Copilot-specific tool guidance (VS Code APIs, etc.)
   - `.github/agents/*.agent.md` — Only Speckit agent guidance + governance authority section
   - All governance rules defer to canonical sources

### Prohibited Agent Instruction Files

The following files are **PROHIBITED** and will be blocked by the CI gate `check-no-agent-grab-bag.sh`:

- `CLAUDE.md` — Use canonical governance sources instead
- `.gemini` — Use canonical governance sources instead
- Any other role-specific instruction "grab bags"

### CI Gate: No Agent Grab Bags

New CI gate `check-no-agent-grab-bag.sh` enforces this policy:

- Blocks commits that add prohibited agent instruction files
- Allows only approved locations:
  - `requirements/workflow/spec.md` (Agent Governance Steering)
  - `contracts/agents.md` (Agent Operating Rules)
  - `.github/copilot-instructions.md` (copilot-specific tool guidance)
  - `.github/agents/*.agent.md` (speckit agents with governance authority)

## Rationale

### Single Source of Truth

Consolidating governance into canonical documents ensures:

- **No drift**: When governance changes, it changes in one place
- **Automatic propagation**: Agents read from canonical sources; they don't need code edits
- **Clear authority**: Canonical docs are the source of truth, not agent files
- **Easier to update**: Governance changes don't require hunting through agent files

### Governance Authority Section Pattern

Each agent includes:

```markdown
## Governance Authority

**[Description of which canonical sources apply to this agent]**

- **Constitution**: [reference]
- **Agent Rules**: `contracts/agents.md`
- **Workflows**: `requirements/workflow/spec.md` § Agent Governance Steering
- **Domain Specs**: `requirements/<domain>/spec.md`
```

This pattern:

- Makes governance sources explicit
- Prevents hardcoding rules
- Enables automatic updates when specs change
- Provides clear reference for agent logic

### Backward Compatibility

- `CLAUDE.md` is removed
- Agents that read `CLAUDE.md` now read canonical sources via "## Governance Authority" sections
- All governance rules are already in canonical sources
- No loss of information; just reorganization

## Consequences

### Positive

- **No more agent instruction drift**: Governance changes automatically apply
- **Clearer authority**: Canonical documents are the source of truth
- **Easier governance updates**: Change the spec once, agents adapt automatically
- **CI enforcement**: `check-no-agent-grab-bag.sh` gate prevents regressions
- **Simpler agent files**: Agents reference governance, don't duplicate it

### Negative

- **Agents must read specs**: Agents need to consult `requirements/workflow/spec.md` for governance patterns
- **No agent-specific rules**: Agents follow the same rules as humans; there are no agent-specific shortcuts

## Implementation

1. Create `requirements/workflow/spec.md` § Agent Governance Steering section ✅
2. Update `contracts/agents.md` to link to spec.md ✅
3. Simplify `.github/copilot-instructions.md` (remove duplicate governance) ✅
4. Remove `CLAUDE.md` ✅
5. Add "## Governance Authority" sections to all speckit agents ✅
6. Create `scripts/check-no-agent-grab-bag.sh` CI gate ✅
7. Integrate gate into `scripts/run-all-gates.sh` ✅

## Related Decisions

- [ADR-0027](./ADR-0027-agent-template-enforcement.md) — Template enforcement for agents
- [ADR-0028](./ADR-0028-constitutional-governance-authority.md) — Constitutional authority for governance
- [ADR-0029](./ADR-0029-contract-lifecycle-procedures.md) — Contract lifecycle procedures
- [Amendment-0003](../constitution/amendments/AMENDMENT-0003-contract-lifecycle.md) — Contract lifecycle amendment

## References

- `requirements/workflow/spec.md` § Agent Governance Steering
- `contracts/agents.md` — Agent Operating Rules
- `scripts/check-no-agent-grab-bag.sh` — CI gate implementation
