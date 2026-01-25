# ADR-0029: Contract Lifecycle Procedures

**Status:** Proposed  
**Date:** 2026-01-25  
**Author:** GitHub Copilot Agent  
**Constitutional Amendment:** [AMENDMENT-0003](../../constitution/amendments/AMENDMENT-0003-contract-lifecycle.md)

## Context

Following establishment of constitutional authority for amendments (AMENDMENT-0001) and ADRs (AMENDMENT-0002), a parallel gap was identified: **the lifecycle for contracts (invariants, hard-stops, agent rules) has no documented procedure or authority.**

### Current State

The repository has three contract files:
1. `contracts/invariants.md` - Conditions that must always be true
2. `contracts/hard-stops.md` - Actions requiring human approval
3. `contracts/agents.md` - Agent behavioral rules

**Gap:** No guidance exists on:
- When/how to add new invariants
- Format requirements for invariants (table vs list vs prose)
- Adding/removing hard-stops
- Amending agent rules
- Authority level (why contracts vs requirements vs constitution)

### Authority Hierarchy

```
Constitution (principles)
├─ Amendments (self-defining)
├─ ADRs (decision history)
├─ Contracts (operational constraints)
├─ Requirements (domain specifications)
└─ Implementation (infra/, ops/, kubernetes/)
```

Contracts sit between constitution and requirements:
- **Below constitution:** Derive from constitutional principles
- **Above requirements:** Apply across all domains

### Observed Patterns

**Invariants show inconsistent format:**
- Network: Table format (VLAN, CIDR, values)
- Storage: Prose with bullet points
- Access: Numbered list
- DNS: Numbered list
- Repository: Numbered list with references
- GitOps: Table format with columns

**Hard-stops have consistent format but no addition procedure.**

**Agent rules have evolved ad-hoc:**
- ADR-0005 added initial procedures
- ADR-0027 added template enforcement
- No documented process for adding rules

### Triggering Event

User asked: "do we have guidelines for adding, amending, and formatting invariants and hard stops?"

Answer: **No.** This is a governance gap that requires constitutional authority.

## Decision

**Establish constitutional authority for contract lifecycle through AMENDMENT-0003.**

### Contract Types Defined

1. **Invariants** - Always-true conditions (network, hardware, access, DNS, structure)
2. **Hard-Stops** - High-risk actions requiring human approval before proceeding
3. **Agent Rules** - Behavioral constraints on agent actions

### Adding Invariants

**Procedure:**
1. Determine category (Network/WAN/Storage/Hardware/Access/DNS/Repository/GitOps)
2. Create supporting ADR documenting rationale
3. Add to `contracts/invariants.md` using appropriate format (table or list)
4. Add CI gate if invariant is checkable
5. PR with ADR reference, code owner approval

**Format:**
- **Structured data** (VLANs, CIDRs, hardware) → Table
- **Rules** (access, DNS, structure) → Numbered list
- **Always include:** Category header, rationale, ADR reference

### Adding Hard-Stops

**Procedure:**
1. Validate constitutional basis (must derive from principle)
2. Create supporting ADR documenting why human approval needed
3. Add to `contracts/hard-stops.md` numbered list
4. Update agent instructions if detection logic needed
5. PR with ADR reference, constitutional review

**Criteria:**
- Represents potential constitutional violation
- Risk is high enough to warrant human judgment
- Agent can detect triggering condition

### Adding/Amending Agent Rules

**Procedure:**
1. Create supporting ADR documenting rationale
2. Update `contracts/agents.md` in appropriate section (Required/Prohibited)
3. Update router files to reference, not restate (no invariant drift)
4. PR with ADR reference, no invariant drift

### Decision Tree: Contract vs Constitution

```
Is this an immutable principle about system architecture?
├─ Yes → CONSTITUTIONAL PRINCIPLE (requires amendment)
└─ No → Is it a constraint that must always hold?
    ├─ Yes → INVARIANT (contracts/invariants.md)
    └─ No → Is it a high-risk action requiring human approval?
        ├─ Yes → HARD-STOP (contracts/hard-stops.md)
        └─ No → Is it an agent behavioral rule?
            ├─ Yes → AGENT RULE (contracts/agents.md)
            └─ No → REQUIREMENT or ADR
```

## Consequences

### Positive

1. **Clear Contract Authority**
   - Contracts have constitutional backing
   - Changes require ADR (enforced by CI)
   - Format requirements eliminate ambiguity

2. **Consistent Format**
   - Tables for structured data (VLANs, hardware)
   - Lists for rules (access, DNS)
   - Rationale always included

3. **Proper Authority Level**
   - Contracts derive from constitution (not arbitrary)
   - Hard-stops validate constitutional basis
   - Requirements can reference contracts authoritatively

4. **Prevent Ad-Hoc Changes**
   - ADR required for all contract changes
   - CI enforcement (canonical changes require ADR)
   - Code owner approval required

5. **Decision Tree Eliminates Ambiguity**
   - Clear guidance on contract vs constitution vs requirement
   - Prevents misclassification (putting invariants in requirements, etc.)

### Negative / Tradeoffs

1. **Constitutional Weight for Contracts**
   - Contract lifecycle is now constitutional (harder to change)
   - Format requirements are constitutional (inflexible)
   - Tradeoff: Stability vs flexibility (stability wins for governance)

2. **ADR Overhead**
   - Every contract change requires ADR
   - Even "obvious" invariants need documentation
   - Mitigation: ADR can be brief if rationale is clear

3. **Retroactive Format Inconsistency**
   - Existing invariants don't all follow format rules
   - Some tables could be lists, some lists could be tables
   - Mitigation: Update opportunistically, not required retroactively

## Alternatives Considered

### Alternative 1: Document procedures in `docs/governance/procedures.md`

**Approach:** Keep contract procedures as explanatory documentation

**Rejected because:**
- Authority hierarchy violation (docs are lowest authority)
- Contracts are constitutional-level governance (need constitutional authority)
- Same reasoning that led to AMENDMENT-0001 and AMENDMENT-0002

### Alternative 2: Create separate contract for contract procedures

**Approach:** Create `contracts/contract-lifecycle.md`

**Rejected because:**
- Self-referential authority issue (contracts can't define their own lifecycle)
- Constitution should define governance procedures for its subordinates
- Inconsistent with AMENDMENT-0001/0002 (amendments and ADRs in constitution)

### Alternative 3: Only document invariant procedures, leave others ad-hoc

**Approach:** Focus on invariants since they're most structured

**Rejected because:**
- Hard-stops and agent rules also lack procedures
- Incomplete governance is worse than no governance
- User question explicitly asked about all contract types

## Implementation

### Files Created

1. `constitution/amendments/AMENDMENT-0003-contract-lifecycle.md`
   - Contract types defined (invariants, hard-stops, agent rules)
   - Adding procedures for each type
   - Format requirements
   - Decision tree

2. `docs/adr/ADR-0029-contract-lifecycle-procedures.md` (this file)
   - Technical/operational rationale

### Files Modified

1. `constitution/constitution.md`
   - Added "Contracts" section (AMENDMENT-0003)
   - Defined contract types and lifecycle
   - Decision tree

2. `constitution/amendments/README.md`
   - Added AMENDMENT-0003 to index

3. `contracts/invariants.md` (header only)
   - Added constitutional authority reference

4. `contracts/hard-stops.md` (header only)
   - Added constitutional authority reference

5. `contracts/agents.md` (header only)
   - Added constitutional authority reference

### Downstream Updates Required

1. `docs/governance/procedures.md`
   - Add "Contract Changes" section referencing AMENDMENT-0003
   - Include decision tree

2. `requirements/workflow/spec.md`
   - Link ADR-0029

## Examples

### Example: Adding Network Invariant

**Scenario:** Need to document that Services VLAN is always 20.

**Procedure:**
1. Create ADR-0030: "Services VLAN Fixed at 20"
2. Add to `contracts/invariants.md`:
   ```markdown
   | Services VLAN | 20 | Fixed for service load balancers |
   ```
3. Link ADR-0030 from `requirements/overlay/spec.md`
4. PR with "ADR-0030" in title

### Example: Adding Hard-Stop

**Scenario:** Prevent agents from disabling Cilium without human approval.

**Procedure:**
1. Validate constitutional basis: Principle 5 (structural safety)
2. Create ADR-0031: "Require Approval for CNI Changes"
3. Add to `contracts/hard-stops.md`:
   ```markdown
   6. **Disable or replace CNI** (Cilium provides network policy enforcement)
   ```
4. Link ADR-0031 from `requirements/overlay/spec.md`
5. PR with "ADR-0031" in title, constitutional review

### Example: Amending Agent Rule

**Scenario:** Require agents to run security scan before every commit.

**Procedure:**
1. Create ADR-0032: "Mandatory Pre-Commit Security Scan"
2. Add to `contracts/agents.md` under "Required Workflows":
   ```markdown
   - Run `gitleaks` scan before every commit
   ```
3. Update `.github/copilot-instructions.md` to reference (not restate)
4. Link ADR-0032 from `requirements/workflow/spec.md`
5. PR with "ADR-0032" in title, no invariant drift

## References

- Constitutional Amendment:
  - [AMENDMENT-0003: Contract Lifecycle Process](../../constitution/amendments/AMENDMENT-0003-contract-lifecycle.md)
- Constitution: [constitution.md](../../constitution/constitution.md)
- Contracts:
  - [invariants.md](../../contracts/invariants.md)
  - [hard-stops.md](../../contracts/hard-stops.md)
  - [agents.md](../../contracts/agents.md)
- Previous Governance ADRs:
  - [ADR-0028: Constitutional Authority for Governance Procedures](ADR-0028-constitutional-governance-authority.md)
  - [ADR-0005: Agent Governance Procedures](ADR-0005-agent-governance-procedures.md) (superseded)
  - [ADR-0027: Agent PR/Issue Template Enforcement](ADR-0027-agent-template-enforcement.md)
- Governance Procedures: [procedures.md](../governance/procedures.md)
