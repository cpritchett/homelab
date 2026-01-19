# Documentation

This directory contains explanatory documentation organized by purpose and authority level.

**Important:** This content is **not normative**. If there is any conflict between docs and `requirements/`, `contracts/`, or `constitution/`, the normative content wins.

## Documentation Hierarchy

### Governance (Normative, Enforceable, Slow-Changing)
- [governance/](governance/) — Policy-level documentation
  - [glossary.md](governance/glossary.md) — Key terminology and definitions
  - [policy-enforcement.md](governance/policy-enforcement.md) — How governance is machine-enforced
  - [security/](governance/security/) — Security policies and procedures
  - [risk/](governance/risk/) — Risk register and management

### Platform Architecture & Rationale (Decision Records)
- [adr/](adr/) — Architectural Decision Records (immutable once merged)
- [platform/](platform/) — Platform design and rationale
  - [rationale.md](platform/rationale.md) — High-level purpose and goals
  - [talos-templating-analysis.md](platform/talos-templating-analysis.md) — Talos configuration analysis

### Operations & Runbooks (How Things Are Run)
- [operations/](operations/) — Operational procedures and guides
  - [stacks/](operations/stacks/) — Container stack deployment
    - [STACKS.md](operations/stacks/STACKS.md) — GitHub-driven stack deployment
    - [STACKS_KOMODO.md](operations/stacks/STACKS_KOMODO.md) — Komodo integration guide
    - [lifecycle.md](operations/stacks/lifecycle.md) — Stack lifecycle management
  - [komodo/](operations/komodo/) — Komodo orchestration platform
    - [KOMODO_SETUP.md](operations/komodo/KOMODO_SETUP.md) — Installation and configuration
  - [runbooks/](operations/runbooks/) — Operational procedures

### Implementation-Specific Guides
- [prompts/](prompts/) — LLM prompts for repository management
  - [prompts.md](prompts/prompts.md) — Common operation prompts

## Doc Invariants

Contributors must follow these rules when adding documentation:

### Authority Levels
- **Governance docs** change slowly and require justification via ADR
- **ADRs** are append-only; create new ADRs to supersede old ones
- **Operations docs** may evolve rapidly as procedures are refined
- **Implementation guides** live under operations/, not governance/

### Placement Rules
- **DO NOT** add new root-level docs to `docs/`
- **Governance policy** → `docs/governance/`
- **Architecture decisions** → `docs/adr/` (with proper ADR format)
- **Platform design rationale** → `docs/platform/`
- **Operational procedures** → `docs/operations/`
- **Tool-specific guides** → `docs/operations/<tool>/`

### Content Guidelines
- Link to canonical sources; don't duplicate normative content
- Explain *why* decisions were made, not just *what* was decided
- Keep implementation guides focused and actionable
- Update links when moving or restructuring content

## Quick Navigation

**Need to understand a decision?** → Check [adr/](adr/) first, then [platform/](platform/)  
**Need to operate something?** → Check [operations/](operations/)  
**Need governance clarification?** → Check [governance/](governance/)  
**Working with AI agents?** → Check [prompts/](prompts/)
