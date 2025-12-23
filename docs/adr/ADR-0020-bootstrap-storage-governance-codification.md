# ADR-0020: Bootstrap, Storage, and Repository Governance Codification

**Status:** Accepted  
**Date:** 2025-12-23  
**Author:** Codex (LLM agent)

## Context

Multiple governance decisions already exist across ADRs (bootstrap sequencing, GitOps layout, storage policy), but the requirements/checklists were incomplete or inconsistent with the repository’s actual structure. CI guardrails also flagged the root directory policy because `bootstrap/` and `kubernetes/` are first-class directories in this repo. Additionally, security fixture locations should align with the canonical `test/` root.

## Decision

1. **Codify bootstrap requirements and checks** in `requirements/bootstrap/`, referencing ADR-0017 and ADR-0019 for the ordering and constraints.
2. **Expand storage requirements and checks** to clarify required StorageClasses, VolSync/Restic expectations, and S3-compatible endpoint flexibility while keeping secret material out of git.
3. **Document GitOps invariants** in `contracts/invariants.md` so CI checks map to explicit, auditable invariants.
4. **Align repository structure policy** with the established root layout by allowing `bootstrap/` and `kubernetes/`, and standardizing security fixtures under `test/`.

## Consequences

- Governance requirements now reflect the actual bootstrap flow, storage classes, and GitOps validation gates.
- Repository structure guardrails no longer conflict with the existing root directories.
- Test fixtures live under the canonical `test/` hierarchy, reducing ambiguity.

## Alternatives Considered

- **Leave requirements implicit** and rely on tribal knowledge — rejected; leads to drift and brittle CI behavior.
- **Relocate `bootstrap/` and `kubernetes/`** under another root — rejected; conflicts with ADR-0018 and current GitOps practices.

## References

- ADR-0017: Talos Bare-Metal Bootstrap Procedure
- ADR-0018: GitOps Structure Refactor for home-ops
- ADR-0019: Bootstrap Sequence Hardening (CRDs, Secrets, Ordering)
- ADR-0010: Longhorn for Non-Database Storage
- `requirements/bootstrap/spec.md`
- `requirements/storage/spec.md`
- `requirements/workflow/repository-structure.md`
