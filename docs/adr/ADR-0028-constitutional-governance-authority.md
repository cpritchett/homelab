# ADR-0028: Establish Constitutional Authority for Governance Procedures

**Status:** Proposed  
**Date:** 2026-01-25  
**Author:** GitHub Copilot Agent  
**Constitutional Amendments:** [AMENDMENT-0001](../../constitution/amendments/AMENDMENT-0001-amendment-process.md), [AMENDMENT-0002](../../constitution/amendments/AMENDMENT-0002-adr-lifecycle.md)

## Context

During implementation of ADR-0027 (agent template enforcement), a governance gap was identified: **the processes for amending the constitution and for evolving ADRs (superseding vs amending) were not defined at an appropriate authority level.**

### Authority Hierarchy Problem

The repository has a clear authority hierarchy:
1. `constitution/` - Immutable principles (highest)
2. `contracts/` - Hard-stops, invariants, agent rules
3. `requirements/` - Domain specifications
4. `docs/` - Explanatory documentation (lowest)

**Gap:** Neither the constitution's own amendment process nor the ADR lifecycle (new/supersede/amend) were defined at constitutional or contract level. These procedures existed only in `docs/governance/procedures.md` (explanatory documentation).

### Legal Precedent

In legal systems (Roberts Rules, parliamentary procedure), authority must be at-level or higher than what it defines:
- Constitution defines its own amendment process
- Bylaws define bylaw amendment process
- ADRs should be governed by constitutional authority

### Observed Pattern

The repository showed inconsistent superseding patterns:
- ADR-0011 → ADR-0012 → ADR-0013 (superseding chain)
- ADR-0021 → ADR-0022 (superseding)
- ADR-0005 → ADR-0027 (superseding)

But **no documented guidance** on:
- When to supersede vs amend
- Amendment format (ADR-0021-amendment-A pattern suggested but not used)
- Status header format for superseding

### Triggering Event

Creating ADR-0027 required choosing between:
1. Create standalone ADR
2. Supersede ADR-0005
3. Amend ADR-0005

Without authoritative guidance, this became an ad-hoc decision. The user correctly identified this as a **constitutional governance gap**.

## Decision

**Establish constitutional authority for governance procedures through two amendments:**

### AMENDMENT-0001: Constitutional Amendment Process

Adds "Amendment Process" section to `constitution/constitution.md` defining:
- How to propose amendments
- Amendment file format (`AMENDMENT-NNNN-topic.md`)
- Relationship to ADRs (amendment + supporting ADR)
- Approval requirements
- Immutability (append-only)

**Authority:** Constitution defines its own amendment process (self-referential authority).

### AMENDMENT-0002: ADR Lifecycle Process

Adds "Architectural Decision Records" section to `constitution/constitution.md` defining:
- When ADRs are required (CI-enforced)
- Creating new ADRs (format, numbering, linking)
- **Superseding ADRs** (when core decision changes)
- **Amending ADRs** (when clarifying/extending)
- Decision tree: supersede vs amend vs new
- Status values (Proposed, Accepted, Superseded, Deprecated)

**Authority:** Constitution establishes ADR lifecycle. Changes to ADR process require constitutional amendment.

## Consequences

### Positive

1. **Clear Authority Hierarchy**
   - Constitution defines its own governance (self-referential)
   - ADR lifecycle has constitutional authority
   - No more ad-hoc decisions on supersede vs amend

2. **Consistent ADR Evolution**
   - Documented superseding process (ADR-NNNN supersedes ADR-MMMM)
   - Documented amendment process (ADR-NNNN-amendment-A format)
   - Decision tree eliminates ambiguity

3. **Constitutional Compliance**
   - Follows legal precedent (authority at-level or higher)
   - Amendment process is self-defining
   - Governance procedures have proper authority

4. **Enables ADR Amendments**
   - Format: `ADR-NNNN-amendment-A.md`
   - Use case: Minor clarifications without superseding
   - Example: ADR-0021-amendment-A for implementation notes

5. **Upstream Authority**
   - `docs/governance/procedures.md` now references constitutional authority
   - CI gates enforce constitutional mandate (not just procedural convention)

### Negative / Tradeoffs

1. **Constitutional Weight**
   - ADR lifecycle is now constitutional (harder to change)
   - Changes to ADR format require constitutional amendment
   - Tradeoff: Stability vs flexibility (stability wins for governance)

2. **Amendment Overhead**
   - ADR amendments require separate file (ADR-NNNN-amendment-A.md)
   - More files to track vs inline edits
   - Mitigation: Amendment format is simple, overhead is minimal

3. **Retroactive Application**
   - Existing ADRs don't follow new format (no amendment references)
   - Status headers may be inconsistent
   - Mitigation: Update as needed, not required retroactively

## Alternatives Considered

### Alternative 1: Document in `contracts/` instead of constitution

**Approach:** Create `contracts/adr-lifecycle.md` and `contracts/amendment-process.md`

**Rejected because:**
- Constitutional amendment process should be IN the constitution (self-referential authority)
- ADR lifecycle defines how governance decisions evolve (constitutional concern)
- Contracts are for operational rules, not meta-governance

### Alternative 2: Keep in `docs/governance/procedures.md`

**Approach:** Leave procedures as explanatory documentation

**Rejected because:**
- Authority hierarchy violation (docs are lowest authority)
- Governance gap exposed during ADR-0027 creation
- No enforcement mechanism (just convention)

### Alternative 3: Only document amendment process, leave ADR lifecycle in docs

**Approach:** Constitutional amendment for amendment process, but ADR lifecycle stays in docs

**Rejected because:**
- ADR lifecycle affects canonical changes (constitutional concern)
- CI gates enforce ADR requirements (needs higher authority)
- Inconsistent: amendment process is constitutional, but ADR process is not

## Implementation

### Files Created

1. `constitution/amendments/AMENDMENT-0001-amendment-process.md`
   - Constitutional amendment format specification
   - Amendment proposal process
   - Approval requirements

2. `constitution/amendments/AMENDMENT-0002-adr-lifecycle.md`
   - ADR creation requirements
   - Superseding process and format
   - Amending process and format (ADR-NNNN-amendment-A)
   - Decision tree

3. `docs/adr/ADR-0028-constitutional-governance-authority.md` (this file)
   - Technical/operational rationale for amendments

### Files Modified

1. `constitution/constitution.md`
   - Added "Amendment Process" section (AMENDMENT-0001)
   - Added "Architectural Decision Records" section (AMENDMENT-0002)
   - Both sections reference detailed amendment files

2. `constitution/amendments/README.md`
   - Added AMENDMENT-0001 and AMENDMENT-0002 to index

### Downstream Updates Required

1. `docs/governance/procedures.md`
   - Update constitutional amendment section to reference AMENDMENT-0001
   - Update ADR creation section to reference AMENDMENT-0002 (constitutional authority)

2. `docs/adr/README.md`
   - Update "Rules" section to reference constitutional authority
   - Add amendment format to status documentation

3. `contracts/agents.md` (optional)
   - Reference constitutional authority for ADR requirements

## References

- Constitutional Amendments:
  - [AMENDMENT-0001: Constitutional Amendment Process](../../constitution/amendments/AMENDMENT-0001-amendment-process.md)
  - [AMENDMENT-0002: ADR Lifecycle Process](../../constitution/amendments/AMENDMENT-0002-adr-lifecycle.md)
- Constitution: [constitution.md](../../constitution/constitution.md)
- Previous Governance ADRs:
  - [ADR-0005: Agent Governance Procedures](ADR-0005-agent-governance-procedures.md) (superseded by ADR-0027)
  - [ADR-0027: Agent PR/Issue Template Enforcement](ADR-0027-agent-template-enforcement.md)
- Governance Procedures: [procedures.md](../governance/procedures.md)
