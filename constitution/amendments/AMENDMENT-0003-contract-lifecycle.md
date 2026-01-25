# AMENDMENT-0003: Contract Lifecycle Process

**Status:** Proposed  
**Date:** 2026-01-25  
**Rationale:** Contracts (invariants, hard-stops, agent rules) require constitutional authority for lifecycle management

## Amendment to Constitution

Add new section **"Contracts"** after Architectural Decision Records section.

## Text

### Contracts

**Purpose:** Contracts define operational constraints that must always hold. There are three types of contracts:

1. **Invariants** (`contracts/invariants.md`) - Conditions that must always be true
2. **Hard-Stops** (`contracts/hard-stops.md`) - Conditions requiring human approval before proceeding
3. **Agent Rules** (`contracts/agents.md`) - What agents may and must not do

**Authority:** This constitution establishes contract lifecycle. Changes to contract format or process require constitutional amendment.

#### 1. Invariants

**Definition:** Technical or operational conditions that must always be true. Violations indicate broken system state.

**Categories:**
- Network Identity (VLANs, CIDRs, DNS zones)
- WAN Constraints (bandwidth, stability)
- Storage Configuration (kernel modules, extensions)
- Hardware Constraints (node count, capabilities)
- Access Rules (traffic flow, egress, overlay)
- DNS Rules (suffixes, split-horizon)
- Repository Structure (file placement, CI enforcement)
- GitOps (Kustomization builds, HelmRelease renders, ordering)

**Adding New Invariants:**

1. **Determine Category**
   - Network/WAN/Storage/Hardware/Access/DNS/Repository/GitOps
   - Create new category if needed

2. **Create Supporting ADR**
   - Document why invariant is needed
   - Link from relevant `requirements/**/spec.md`
   - ADR must precede contract change

3. **Add to `contracts/invariants.md`**
   - Use table format for structured data (VLANs, CIDRs, hardware)
   - Use numbered list for access/DNS rules
   - Add rationale if not obvious
   - Include reference to supporting ADR

4. **Update CI Gates** (if checkable)
   - Add validation script in `scripts/` if invariant can be tested
   - Wire into `scripts/run-all-gates.sh` if blocking
   - Add to "Invariants (informational)" section if non-blocking

5. **PR Requirements**
   - ADR reference in PR title/body
   - All CI gates must pass
   - Code owner approval required

**Amending Invariants:**

- **Relaxing constraint:** Requires ADR + constitutional review (may violate principles)
- **Tightening constraint:** Requires ADR documenting rationale
- **Clarifying wording:** Requires ADR if substantive, PR review if editorial
- **Removing invariant:** Requires ADR + proof it no longer applies

**Format Requirements:**
```markdown
## [Category] Invariants

[Table for structured data OR numbered list for rules]

Rationale: [If not obvious from context]

See: [ADR-NNNN](../../docs/adr/ADR-NNNN-topic.md)
```

#### 2. Hard-Stops

**Definition:** Actions that agents must stop and request human approval before proceeding. Represent potential constitutional violations or high-risk changes.

**Examples:**
- Exposing services directly to WAN
- Publishing internal DNS publicly
- Allowing non-console access to Management
- Installing overlay on Management VLAN
- Overriding public FQDNs internally

**Adding New Hard-Stops:**

1. **Validate Constitutional Basis**
   - Hard-stop must derive from constitutional principle
   - If not, consider whether principle needs amendment first

2. **Create Supporting ADR**
   - Document rationale for requiring human approval
   - Explain what could go wrong if automated
   - Link from `requirements/workflow/spec.md` or relevant domain spec

3. **Add to `contracts/hard-stops.md`**
   - Use numbered list format
   - State condition clearly and specifically
   - Avoid ambiguity (agents must be able to detect condition)

4. **Update Agent Instructions**
   - Add detection logic to `contracts/agents.md` if needed
   - Ensure agents can recognize triggering condition

5. **PR Requirements**
   - ADR reference in PR title/body
   - Justification for why human approval is needed
   - Examples of triggering conditions

**Amending Hard-Stops:**

- **Adding hard-stop:** Requires ADR + constitutional review
- **Removing hard-stop:** Requires ADR + proof risk is mitigated
- **Clarifying wording:** Requires ADR if changes scope, PR review if editorial
- **Relaxing condition:** Requires ADR + constitutional review (may enable violations)

**Format Requirements:**
```markdown
# Hard-Stop Conditions
**Effective:** YYYY-MM-DD

Agents must **stop and ask** before proceeding if a proposed change would:

1. [Action description] ([rationale in parentheses])
2. [Action description] ([rationale in parentheses])
...

## Rationale

[Overall explanation of hard-stop philosophy]

See: [constitution/constitution.md](../constitution/constitution.md)
See: [ADR-NNNN](../docs/adr/ADR-NNNN-topic.md)
```

#### 3. Agent Rules

**Definition:** Operational rules governing what agents may and must not do when interacting with the repository.

**Categories:**
- Required workflows (PR templates, ADR creation, gate validation)
- Prohibited actions (bypassing gates, committing secrets, weakening security)
- Authority levels (what requires human approval)
- Classification rules (canonical vs non-canonical changes)

**Adding/Amending Agent Rules:**

1. **Create Supporting ADR**
   - Document why rule is needed
   - Link from `requirements/workflow/spec.md`

2. **Update `contracts/agents.md`**
   - Add to appropriate section (Required/Prohibited)
   - Use clear, unambiguous language
   - Provide examples if complex

3. **Update Router Files** (if needed)
   - `.github/copilot-instructions.md`
   - `agents.md`
   - `CLAUDE.md`
   - Reference contract, don't restate (per invariant drift rules)

4. **PR Requirements**
   - ADR reference in PR title/body
   - No invariant drift in router files

**Format Requirements:**
```markdown
# Agent Operating Rules

## Required Workflows
Agents MUST:
- [Action 1]
- [Action 2]

## Prohibited Actions
Agents MUST NOT:
- [Action 1]
- [Action 2]

## Authority Levels
[What requires human approval vs agent autonomy]

See: [ADR-NNNN](../../docs/adr/ADR-NNNN-topic.md)
```

#### 4. Contract vs Constitution Decision Tree

```
Is this an immutable principle about system architecture?
├─ Yes → CONSTITUTIONAL PRINCIPLE (requires amendment)
└─ No → Is it a constraint that must always hold?
    ├─ Yes → INVARIANT (contracts/invariants.md)
    └─ No → Is it a high-risk action requiring human approval?
        ├─ Yes → HARD-STOP (contracts/hard-stops.md)
        └─ No → Is it an agent behavioral rule?
            ├─ Yes → AGENT RULE (contracts/agents.md)
            └─ No → REQUIREMENT or ADR (requirements/ or docs/adr/)
```

## Downstream Impacts

- `contracts/invariants.md`: Add header referencing constitutional authority
- `contracts/hard-stops.md`: Add header referencing constitutional authority
- `contracts/agents.md`: Add header referencing constitutional authority
- `docs/governance/procedures.md`: Update contract change procedures
- `scripts/no-invariant-drift.sh`: Validate contract files follow format

## References

- Constitution: [constitution.md](../constitution.md)
- Amendment Index: [README.md](./README.md)
- Contracts:
  - [invariants.md](../../contracts/invariants.md)
  - [hard-stops.md](../../contracts/hard-stops.md)
  - [agents.md](../../contracts/agents.md)
- Governance Procedures: [docs/governance/procedures.md](../../docs/governance/procedures.md)
