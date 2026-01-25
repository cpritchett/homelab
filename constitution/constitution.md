# Homelab Infrastructure Constitution
**Domain:** hypyr.space  
**Effective:** 2025-12-14

## Purpose
This constitution defines immutable principles governing networking, DNS intent, external ingress, and management access.

If a change conflicts with this constitution, the change is invalid unless the constitution itself is amended.

## Principles
1. **Management is Sacred and Boring**  
   The management network remains isolated, predictable, and minimally reachable.

2. **DNS Encodes Intent**  
   Names describe trust boundaries. Public and internal services do not share identical names.

3. **External Access is Identity-Gated**  
   External access is mediated by Cloudflare Tunnel + Access, not WAN exposure.

4. **Routing Does Not Imply Permission**  
   Reachability does not grant authorization; policy boundaries remain authoritative.

5. **Prefer Structural Safety Over Convention**  
   Make unsafe actions hard; avoid relying on memory, tribal knowledge, or "we'll be careful."

---

## Amendment Process

**Authority:** This constitution is the highest authority in this repository. To amend it:

1. **Propose Amendment**
   - Create amendment file: `constitution/amendments/AMENDMENT-NNNN-topic.md`
   - Use sequential numbering (0001, 0002, etc.)
   - Document rationale, affected principles, and downstream impacts

2. **Create Supporting ADR**
   - Document technical/operational rationale in `docs/adr/ADR-NNNN-topic.md`
   - Link amendment from ADR and vice versa

3. **Update Constitution**
   - Modify this file with amendment text
   - Add amendment reference to modified section
   - Update `constitution/amendments/README.md` index

4. **Update Downstream Documents**
   - Review and update all affected contracts (`contracts/`)
   - Review and update all affected requirements (`requirements/`)
   - Update agent instructions if governance changes

5. **Approval Requirements**
   - Constitutional amendments require code owner approval
   - All CI gates must pass
   - Extended review period (minimum 24 hours)

**Amendment Format:** See [AMENDMENT-0001](amendments/AMENDMENT-0001-amendment-process.md) for complete format specification.

**Immutability:** Amendments are append-only. To reverse an amendment, create a new amendment that supersedes it.

---

## Architectural Decision Records

**Purpose:** ADRs document architectural and governance decisions with rationale. ADRs are append-only history that evolves through superseding and amendment.

**Authority:** This constitution establishes the ADR lifecycle. Changes to ADR process require constitutional amendment.

### Creating New ADRs

**When Required:**
- Changes to `constitution/`, `contracts/`, or `requirements/` (mandatory, CI-enforced)
- Significant architectural decisions affecting multiple domains
- Security-impacting decisions

**Numbering:** Sequential starting from ADR-0001. Use next available number.

**Location:** `docs/adr/ADR-NNNN-short-title.md`

**Linking:** All canonical ADRs MUST be linked from relevant `requirements/**/spec.md` (CI-enforced).

### Superseding ADRs

**When to Supersede:** Decision is being fundamentally replaced or made obsolete.

**Process:**
1. Create new ADR-NNNN with header: `**Supersedes:** ADR-MMMM`
2. Update old ADR status: `**Status:** Superseded by ADR-NNNN`
3. Keep old ADR in place (append-only, historical record)

### Amending ADRs

**When to Amend:** Minor clarifications or extensions without changing core decision.

**Format:** Create `docs/adr/ADR-NNNN-amendment-A.md` (use letters: A, B, C...)

**Process:**
1. Create amendment file with `**Amends:** ADR-NNNN` header
2. Update original ADR: `**Amendments:** [Amendment A](ADR-NNNN-amendment-A.md)`
3. Original ADR remains unchanged (append-only)

### Decision Tree: Supersede vs Amend

```
Is the core decision changing?
├─ Yes → SUPERSEDE (new ADR-NNNN)
└─ No → Is this just clarification/extension?
    ├─ Yes → AMEND (ADR-NNNN-amendment-A)
    └─ No, it's related but separate → NEW ADR
```

**Complete ADR lifecycle specification:** See [AMENDMENT-0002](amendments/AMENDMENT-0002-adr-lifecycle.md)
