# ADR-0023: Scripts and Stacks Directory Classification

**Status:** Accepted
**Date:** 2026-01-25
**Author:** Claude Sonnet 4.5

## Context

ADR-0005 established a 4-tier change classification system to determine when ADRs are required:

1. Documentation-only changes (no ADR unless documenting new decision)
2. Non-canonical changes (`infra/`, `ops/`, scripts) - ADR optional
3. Canonical changes (`constitution/`, `contracts/`, `requirements/`) - ADR required
4. Constitutional amendments - ADR required + amendment file

However, this classification created ambiguity in two areas:

1. **`/scripts` directory** - Contains both:
   - **Governance enforcement scripts** that encode constitutional rules (e.g., `require-adr-on-canonical-changes.sh`, `no-invariant-drift.sh`, `adr-must-be-linked-from-spec.sh`)
   - **Validation/testing helpers** that check implementation correctness (e.g., `check-crd-ordering.sh`, `check-kustomize-build.sh`, `test-talos-templates.sh`)

   The current classification treats all scripts as non-canonical, potentially allowing governance rules to be modified without ADR documentation.

2. **`/stacks` directory** - Added in ADR-0020 as a first-class root directory for NAS deployment manifests (Docker Compose stacks). While ADR-0020 and ADR-0022 define its structure and management model (Komodo-managed, self-contained), `docs/governance/procedures.md` doesn't explicitly include it in the non-canonical classification list.

This ambiguity creates confusion about:
- When ADRs are required for script changes
- Whether stacks are governed by the same rules as infra/ops
- How to classify changes that affect governance enforcement vs operational tooling

## Decision

We extend ADR-0005's classification system with the following clarifications:

### 1. Split `/scripts` Classification

**Canonical scripts** (changes require ADR):
- `adr-must-be-linked-from-spec.sh` - Enforces ADR linkage requirement
- `require-adr-on-canonical-changes.sh` - Enforces ADR requirement for canonical changes
- `no-invariant-drift.sh` - Prevents invariant leakage into implementation files
- `enforce-root-structure.sh` - Validates repository structure via Conftest
- `run-all-gates.sh` - Orchestrates all governance gates

These scripts **encode governance rules** derived from the constitution and contracts. Modifying their logic changes what is enforced, making them part of the governance framework itself.

**Non-canonical scripts** (ADR optional, only if introducing new patterns):
- `check-*.sh` - Kubernetes, Talos, and security validation helpers
- `test-*.sh` - Template and security testing scripts
- Any scripts under `/stacks/scripts/` - Stack-specific operational helpers

These scripts **validate implementation correctness** but don't enforce governance boundaries. Changes affect what is checked, not what is required by governance.

### 2. Explicitly Classify `/stacks` as Non-Canonical

The `/stacks` directory is **non-canonical**. Changes to stacks (adding applications, updating compose files, modifying environment variables) are implementation decisions, not governance decisions.

**ADR required only if:**
- Changing the stacks deployment model itself (e.g., switching from Komodo, reintroducing registry.toml)
- Changing how secrets are materialized or managed
- Redefining what constitutes "platform" vs "application" tier
- Making architectural decisions that affect multiple stacks

**ADR NOT required for:**
- Adding new application stacks
- Updating Docker Compose configurations
- Modifying `.env.example` files
- Updating image versions or dependencies
- Adding stack-specific helper scripts

### 3. Update Classification Table

The updated classification:

| Classification | Directories/Files | ADR Required? |
|----------------|-------------------|---------------|
| **Canonical** | `constitution/`, `contracts/`, `requirements/` | Always |
| **Canonical** | `scripts/` (governance enforcement only) | Always |
| **Non-Canonical** | `infra/`, `ops/`, `stacks/` | Optional* |
| **Non-Canonical** | `scripts/` (validation/testing helpers) | Optional* |
| **Doc-only** | `docs/` (non-ADR documentation) | No** |

\* ADR optional: Only required if introducing new architectural patterns, affecting multiple domains, or having security implications.
\*\* ADR not required unless documenting a new architectural decision.

## Consequences

### Positive

1. **Prevents Governance Bypass** - Governance enforcement scripts can't be weakened without documented ADR rationale
2. **Clear ADR Requirements** - Developers know exactly which script changes require ADRs
3. **Maintains Flexibility** - Validation and testing scripts remain easy to modify and improve
4. **Explicit Stacks Governance** - `/stacks` classification is now unambiguous and documented
5. **Consistent with Existing ADRs** - Aligns with ADR-0020 (stacks structure) and ADR-0022 (Komodo management)
6. **Traceability** - Changes to governance enforcement logic are traceable through ADRs

### Negative / Tradeoffs

1. **More Complexity** - Single directory (`/scripts`) now has split classification
2. **Potential Confusion** - Developers must determine if a script is "governance enforcement" or "validation"
3. **No Automated Enforcement** - CI gates don't automatically distinguish canonical vs non-canonical scripts

**Mitigations:**
- **Clear List** - This ADR provides explicit list of canonical scripts
- **Documentation** - `docs/governance/procedures.md` will include classification guidance
- **Small Set** - Only 5 scripts are canonical (governance enforcement), making classification manageable
- **Stable Set** - Governance enforcement scripts rarely change; new scripts are typically validation helpers

## Alternatives Considered

### Alternative 1: All Scripts Canonical

Treat all `/scripts` as canonical, requiring ADRs for any script changes.

**Rejected because:**
- Too restrictive for operational tooling
- Would require ADRs for minor validation improvements
- Discourages iterative improvement of testing infrastructure
- No governance risk from modifying validation logic
- Would slow down legitimate improvements

### Alternative 2: All Scripts Non-Canonical

Keep all `/scripts` as non-canonical, never requiring ADRs for script changes.

**Rejected because:**
- Allows governance rules to be weakened without documentation
- Could bypass constitutional enforcement through script modification
- Loses traceability for why enforcement logic changed
- Creates risk of accidental governance drift
- Doesn't align with "governance as code" principle

### Alternative 3: Separate Directory for Governance Scripts

Create `/governance/scripts` for enforcement, keep `/scripts` for validation.

**Rejected because:**
- Unnecessary file reorganization
- Breaks existing CI workflows and references
- Adds complexity without proportional benefit
- `/scripts` already contains both types (historical precedent)
- Split classification achieves the same governance without file moves

### Alternative 4: Treat Stacks as Canonical

Require ADRs for all stacks changes, treating them as governance decisions.

**Rejected because:**
- Too heavyweight for application deployment
- Stacks are implementation artifacts, not governance rules
- Would require ADRs for routine operational changes (version updates, config tweaks)
- Contradicts ADR-0020 and ADR-0022 (stacks are implementation-level)
- ADR-0005's non-canonical classification already covers this use case appropriately

## References

- **Extends:** [ADR-0005: Agent Governance Procedures](./ADR-0005-agent-governance-procedures.md)
- **Related:** [ADR-0020: Bootstrap, Storage, Repository Governance, and NAS Stacks Codification](./ADR-0020-bootstrap-storage-governance-codification.md)
- **Related:** [ADR-0022: Komodo-Managed NAS Stacks](./ADR-0022-truenas-komodo-stacks.md)
- **Updates:** [docs/governance/procedures.md](../governance/procedures.md)
