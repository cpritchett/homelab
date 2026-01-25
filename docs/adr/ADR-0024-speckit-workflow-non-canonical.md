# ADR-0024: Speckit Workflow for Non-Canonical Implementation

**Status:** Accepted
**Date:** 2026-01-25
**Author:** Claude Sonnet 4.5

## Context

The repository has a mature governance system for canonical changes:

- **Constitution** defines immutable principles
- **Contracts** define hard-stops and invariants
- **Requirements** define domain specifications
- **ADRs** document architectural decisions with full context, alternatives, and consequences

This ADR-driven process works well for governance changes but is heavyweight for non-canonical implementation work (adding applications to `/stacks`, deploying services to `/kubernetes`, provisioning infrastructure in `/infra`).

### Current State

1. **Templates exist** in `.specify/templates/` but are undocumented:
   - `spec-template.md` - Requirements (MUST/MUST NOT/SHOULD)
   - `plan-template.md` - Approach and architecture
   - `tasks-template.md` - Ordered tasks with dependencies

2. **Templates are used inconsistently**:
  - Kubernetes platform layer uses spec-like files (`specs/005-k8s-platform/spec.md`)
   - Stacks have no consistent planning artifacts
   - Infrastructure changes have no standard workflow
   - No guidance on when to use templates vs ADRs

3. **Problems with current approach**:
   - Implementation work lacks structured planning
   - No consistent way to document requirements and acceptance criteria
   - Difficult to trace why implementation decisions were made
   - Can't distinguish between "quick fix" and "considered decision"
   - No clear guidance on appropriate level of documentation for non-canonical changes

### Need

We need a **lightweight but structured workflow** for non-canonical work that:
- Provides consistency without ADR overhead
- Documents requirements and acceptance criteria
- Enables traceable decision-making
- Scales from simple applications to complex infrastructure
- Integrates with existing CI gates (doesn't change ADR requirements)

## Decision

We establish the **Speckit Workflow** as the official process for non-canonical implementation work. This workflow uses the existing `.specify/templates/` to create lightweight, co-located planning artifacts.

### Workflow Phases

**1. Constitution Review**
- Review `constitution/constitution.md` for principle alignment
- Check `contracts/hard-stops.md` for human approval requirements
- Verify `contracts/invariants.md` compliance (VLANs, CIDRs, DNS zones)
- Ensure no violation of domain requirements in `requirements/*/spec.md`

**2. Specify (Requirements)**
- Create `spec.md` using `.specify/templates/spec-template.md`
- Define MUST/MUST NOT/SHOULD requirements
- Document validation criteria (checks)
- Link to related ADRs and governance specs

**3. Plan (Architecture)**
- Create `plan.md` using `.specify/templates/plan-template.md`
- Document context (what problem are we solving?)
- Describe approach (how will we solve it?)
- List tech stack, dependencies, risks
- Make architecture decisions explicit

**4. Tasks (Execution)**
- Create `tasks.md` using `.specify/templates/tasks-template.md`
- Break work into ordered tasks with dependencies
- Define acceptance criteria for each task
- Document completion criteria for the overall work

**5. Implement (Execution)**
- Execute tasks sequentially
- Verify acceptance criteria as you go
- Update artifacts if requirements/approach changes
- Ensure CI gates pass before merging

### Scope: When to Use Speckit

**Use Speckit for:**
- Adding new applications to `/stacks` (e.g., new platform or app-tier services)
- Major infrastructure changes in `/infra` (e.g., new network segments, storage systems)
- New operational procedures in `/ops` (e.g., backup strategies, runbooks)
- Non-trivial changes affecting multiple components
- Work where you want traceable requirements and acceptance criteria

**Do NOT use Speckit for:**
- **Bug fixes within established patterns** - Fix the bug, document in commit message
- **Routine updates** - Version bumps, config tweaks within existing patterns
- **Documentation-only changes** - Edit docs directly
- **Canonical changes** - Use full ADR process instead (constitution, contracts, requirements)

### Artifact Locations

**Non-canonical artifacts** (spec.md, plan.md, tasks.md) are **co-located with implementation**:

```
stacks/
  platform/
    ingress/
      spec.md          # Requirements for ingress stack
      plan.md          # Architecture decisions
      tasks.md         # Implementation tasks
      compose.yaml     # Implementation
      .env.example

kubernetes/
  clusters/
    homelab/
      platform/
        spec.md        # Requirements for platform layer
        kustomization.yaml

infra/
  networking/
    spec.md            # Requirements for network infrastructure
    plan.md
    tasks.md
    *.tf               # Terraform implementation
```

**Canonical artifacts** (governance specs) remain in `requirements/*/spec.md` - these define domain-level governance rules, not implementation specifics.

### Relationship to ADRs

Speckit workflow **does NOT replace ADRs**:

- **ADRs are required** for canonical changes (constitution, contracts, requirements) per ADR-0005
- **ADRs are optional** for non-canonical changes that introduce new architectural patterns, affect multiple domains, or have security implications
- **Speckit artifacts** provide lightweight documentation for implementation decisions
- **Both can coexist** - use ADR for architectural decision, use spec/plan/tasks for implementation

Example: ADR documents "We will use Komodo to manage stacks" (ADR-0022). Spec documents "Authentik stack MUST support LDAP and OAuth providers" (implementation requirement).

### Integration with CI Gates

Speckit workflow does **NOT change** CI gate requirements from ADR-0005:

- All non-canonical changes must still pass CI gates (no invariant drift, secret scanning, etc.)
- Canonical scripts (`require-adr-on-canonical-changes.sh`) remain unchanged
- ADR requirements remain enforced as per ADR-0005 classification
- Speckit provides planning structure, not governance exemption

### Templates

Use existing templates in `.specify/templates/`:

- **spec-template.md** - Overview, MUST/MUST NOT/SHOULD, Checks, Links
- **plan-template.md** - Context, Approach, Tech Stack, Architecture, Risks, Dependencies
- **tasks-template.md** - Prerequisites, Tasks (with description, files, acceptance criteria, dependencies), Completion Criteria

These templates are intentionally lightweight (10-20 lines each) to reduce overhead.

## Consequences

### Positive

1. **Structured Implementation** - Clear workflow from requirements → architecture → tasks → execution
2. **Traceable Decisions** - Implementation decisions are documented without ADR overhead
3. **Consistent Pattern** - Same workflow across stacks, infra, ops
4. **Lightweight Documentation** - Co-located artifacts, minimal templates
5. **Clear Acceptance Criteria** - Tasks define what "done" means
6. **Doesn't Change Governance** - ADR requirements unchanged, just adds planning for non-canonical work
7. **Formalizes Existing Practice** - Templates already exist and are used; this ADR makes it official
8. **Scalable** - Works for simple single-stack apps and complex multi-component infrastructure

### Negative / Tradeoffs

1. **More Artifacts** - Creates 1-3 additional files per implementation
2. **Overhead for Small Changes** - Speckit might be overkill for trivial changes (guidance: skip it)
3. **No Enforcement** - CI doesn't require speckit artifacts (intentional - use judgment)
4. **Learning Curve** - Developers must learn when to use Speckit vs ADRs vs neither

**Mitigations:**
- **Clear Scope Guidance** - "When to Use" section makes decision obvious
- **Lightweight Templates** - 10-20 lines, not heavyweight documents
- **Co-location** - Artifacts live with code, easy to maintain
- **Detailed Procedures** - `docs/governance/speckit-workflow.md` provides walkthrough and examples
- **Optional Enforcement** - Use judgment; only create artifacts that add value

## Alternatives Considered

### Alternative 1: No Formal Process

Allow non-canonical work to proceed without structured planning.

**Rejected because:**
- Leads to inconsistent implementation
- No traceable decision-making for implementation choices
- Difficult to onboard new contributors
- Can't distinguish "quick fix" from "considered decision"
- Loses documentation of requirements and acceptance criteria
- Templates exist but are unused/undiscovered

### Alternative 2: Require ADRs for All Work

Extend ADR requirement to all non-canonical changes.

**Rejected because:**
- Too heavyweight for implementation work
- ADR format (Context, Decision, Consequences, Alternatives) doesn't fit implementation planning
- Would require ADRs for routine changes
- Contradicts ADR-0005's "optional for non-canonical" classification
- Discourages iterative development

### Alternative 3: Separate Tooling/Commands

Create CLI tools (`speckit init`, `speckit plan`, etc.) to manage workflow.

**Rejected because:**
- Unnecessary tooling complexity
- Templates are sufficient (just copy and fill in)
- Repository has no existing CLI infrastructure
- Markdown files are simple and universal
- Tooling would need maintenance and documentation
- Adds dependency and learning curve

### Alternative 4: ADR-Lite Format

Create lighter "ADR-Lite" format for non-canonical work, stored in `docs/adr/`.

**Rejected because:**
- Creates two ADR systems (confusing)
- Artifacts should be co-located with implementation, not centralized in `docs/`
- Existing templates (spec/plan/tasks) already provide the structure needed
- Would still require differentiating "ADR" from "ADR-Lite" (complexity)
- Co-location makes artifacts easier to maintain and discover

## References

- **Extends:** [ADR-0005: Agent Governance Procedures](./ADR-0005-agent-governance-procedures.md)
- **Related:** [ADR-0023: Scripts and Stacks Directory Classification](./ADR-0023-scripts-stacks-classification.md)
- **Templates:** [.specify/templates/](../../.specify/templates/)
- **Detailed Procedures:** [docs/governance/speckit-workflow.md](../governance/speckit-workflow.md)
