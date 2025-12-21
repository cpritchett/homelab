# ADR-0005: Agent Governance Procedures

**Status:** Accepted  
**Date:** 2025-12-21  
**Author:** GitHub Copilot Agent

## Context

The repository has a well-defined governance structure with constitutional principles, contracts, invariants, and domain requirements. CI workflows enforce these rules through automated gates. However, agent instructions were minimal and did not explicitly document:

1. What CI gates exist and how to run them locally
2. When ADRs are required and how to create them
3. The complete definition of done for agent-generated changes
4. Detailed procedures for different change classifications
5. A strict contract that agents must follow

This led to potential for:
- Agents completing work without running required gates
- Canonical changes without proper ADR documentation
- Lack of clarity on governance procedures
- Inconsistent compliance with constitutional principles

## Decision

We create comprehensive governance documentation and update agent instructions to enforce compliance:

### Created Documents

1. **docs/governance/ci-gates.md** - Complete reference for all CI gates including:
   - What each gate validates
   - How to run locally
   - Failure modes and fixes
   - Required status checks per ruleset

2. **docs/governance/procedures.md** - Change procedures including:
   - Change classification rubric (doc-only, non-canonical, canonical, constitutional)
   - When ADRs are required
   - How to create ADRs
   - PR format requirements
   - Domain-specific procedures
   - Validation commands

3. **docs/governance/agent-contract.md** - Strict agent contract defining:
   - What agents MUST NEVER do
   - What agents MUST ALWAYS do
   - Definition of done checklist
   - Common mistakes to avoid
   - Escalation procedures

4. **scripts/run-all-gates.sh** - Convenience script to run all gates locally

5. **.github/workflows/adr-linked.yml** - Missing workflow for `adr-must-be-linked-from-spec` gate

### Updated Files

1. **.github/copilot-instructions.md** - Added governance procedure references and pre-completion checklist
2. **agents.md** - Added definition of done, quick commands, and change rubric

### Process Changes

Agents must now:
- Run all gates before completing work
- Create ADR for any canonical change
- Classify changes correctly
- Provide evidence of compliance in PR
- Follow strict contract in agent-contract.md

## Consequences

### Positive

1. **Explicit Requirements** - Agents have clear, documented procedures to follow
2. **Gate Coverage** - All required status checks have workflows and documentation
3. **Reduced Errors** - Running gates locally catches issues before PR submission
4. **Consistent Compliance** - Agent contract ensures uniform behavior across all agents
5. **Traceability** - ADR requirements ensure governance changes are documented
6. **Self-Service** - Documentation enables agents and humans to understand requirements without guessing

### Negative / Tradeoffs

1. **More Documentation** - Added ~33KB of documentation that must be maintained
2. **Longer Agent Instructions** - Router files now reference more documents (but avoid restating invariants)
3. **Increased Agent Work** - Agents must run gates and create ADRs (but this work was already required, just not enforced)
4. **Learning Curve** - New contributors must read more documentation

Mitigations:
- Router files remain thin by linking rather than restating
- Documentation is organized hierarchically (quick reference → detailed guides)
- Scripts automate gate execution (`run-all-gates.sh`)
- Agent contract provides checklist template for copy-paste
- Clear change rubric makes requirements obvious

## Alternatives Considered

### Alternative 1: Minimal update to agent instructions
Just add a line "run gates before completing" to agents.md

**Rejected because:**
- Doesn't document what gates exist
- Doesn't explain how to run them
- Doesn't clarify when ADRs are required
- Agents would still need to discover procedures through trial and error

### Alternative 2: Embed all procedures in agents.md
Put complete gate documentation and procedures directly in the router file

**Rejected because:**
- Violates "thin router" principle
- Would trigger invariant drift gate
- Makes router file too long and hard to maintain
- Mixes authoritative routing with detailed procedures

### Alternative 3: Only document gates, skip agent contract
Create ci-gates.md and procedures.md but no agent-contract.md

**Rejected because:**
- Agent contract provides essential "must/must not" clarity
- Serves as quick reference for agents
- Includes ready-to-use checklist template
- Consolidates scattered requirements into one enforceable contract

### Alternative 4: Create Makefile/Taskfile instead of shell script
Use task runner for gate execution

**Rejected because:**
- Repository has no existing Make/Task infrastructure
- Shell script is simpler and more portable
- Gates scripts are already bash
- No need for task dependencies or complex orchestration

## References

- Constitution: [constitution/constitution.md](../../constitution/constitution.md)
- Agent rules: [contracts/agents.md](../../contracts/agents.md)
- Ruleset: `.github/rulesets/branch-default.json`
- Existing gate scripts: `scripts/*.sh`
