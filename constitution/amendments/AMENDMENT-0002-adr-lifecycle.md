# AMENDMENT-0002: ADR Lifecycle Process

**Status:** Accepted  
**Date:** 2026-01-25  
**Rationale:** ADR lifecycle rules (new, supersede, amend) require constitutional authority

## Amendment to Constitution

Add new section **"Architectural Decision Records"** after Amendment Process section.

## Text

### Architectural Decision Records

**Purpose:** ADRs document architectural and governance decisions with rationale. ADRs are append-only history that evolves through superseding and amendment.

**Authority:** This constitution establishes the ADR lifecycle. Changes to ADR process require constitutional amendment.

#### 1. Creating New ADRs

**When Required:**
- Changes to `constitution/`, `contracts/`, or `requirements/` (mandatory, CI-enforced)
- Significant architectural decisions affecting multiple domains
- Security-impacting decisions

**Format:**
```markdown
# ADR-NNNN: Short Title

**Status:** Proposed | Accepted | Superseded | Deprecated  
**Date:** YYYY-MM-DD  
**Author:** Name

## Context
Situation and problem being solved

## Decision
What was decided

## Consequences
Positive and negative outcomes

## Alternatives Considered
What was rejected and why

## References
- Links to related specs, ADRs, amendments
```

**Numbering:** Sequential starting from ADR-0001. Use next available number.

**Location:** `docs/adr/ADR-NNNN-short-title.md`

**Linking:** All canonical ADRs MUST be linked from relevant `requirements/**/spec.md` (CI-enforced).

#### 2. Superseding ADRs

**When to Supersede:**
- Decision is being fundamentally replaced
- New approach makes previous decision obsolete
- Evolution is substantial enough to warrant new ADR

**Process:**
1. Create new ADR-NNNN with full context and decision
2. Add to new ADR header: `**Supersedes:** ADR-MMMM`
3. Update old ADR status: `**Status:** Superseded by ADR-NNNN`
4. Update old ADR header: `**Superseded by:** ADR-NNNN (YYYY-MM-DD) - Brief reason`
5. Link new ADR from relevant requirements specs
6. Keep old ADR in place (append-only, historical record)

**Example:**
```markdown
# ADR-0027: New Approach (supersedes ADR-0005)

**Status:** Accepted  
**Supersedes:** ADR-0005  
...
```

#### 3. Amending ADRs

**When to Amend:**
- Minor clarifications or corrections
- Adding examples or implementation notes
- Extending decision without changing core rationale

**Format:** Create amendment file: `docs/adr/ADR-NNNN-amendment-A.md` (use letters: A, B, C...)

**Process:**
1. Create `ADR-NNNN-amendment-A.md` with amendment text
2. Update original ADR to reference amendment: `**Amendments:** [Amendment A](ADR-NNNN-amendment-A.md) (YYYY-MM-DD)`
3. Amendment file documents what changed and why
4. Original ADR remains unchanged (append-only)

**Amendment Format:**
```markdown
# ADR-NNNN Amendment A: Short Description

**Date:** YYYY-MM-DD  
**Amends:** [ADR-NNNN](ADR-NNNN-original-title.md)

## What Changed
Description of amendment

## Rationale
Why amendment was needed

## Impact
What this affects
```

**When NOT to Amend:**
- If decision fundamentally changes → Supersede instead
- If contradiction arises → Supersede instead
- If significant new context → Create new ADR

#### 4. Supersede vs Amend Decision Tree

```
Is the core decision changing?
├─ Yes → SUPERSEDE (new ADR-NNNN)
└─ No → Is this just clarification/extension?
    ├─ Yes → AMEND (ADR-NNNN-amendment-A)
    └─ No, it's related but separate → NEW ADR
```

#### 5. ADR Status Values

- **Proposed:** Under review, not yet accepted
- **Accepted:** Active decision in force
- **Superseded:** Replaced by newer ADR, kept for history
- **Deprecated:** No longer recommended but not superseded

## Downstream Impacts

- `docs/adr/README.md`: Update to reference constitutional authority for ADR lifecycle
- `docs/governance/procedures.md`: Update ADR creation section to reference this amendment
- `contracts/agents.md`: Reference constitutional authority for ADR requirements
- `scripts/require-adr-on-canonical-changes.sh`: Gate enforces constitutional mandate

## References

- Constitution: [constitution.md](../constitution.md)
- Amendment Index: [README.md](./README.md)
- ADR Index: [docs/adr/README.md](../../docs/adr/README.md)
- Governance Procedures: [docs/governance/procedures.md](../../docs/governance/procedures.md)
