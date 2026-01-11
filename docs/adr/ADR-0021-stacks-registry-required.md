# ADR-0021: Require Registry for NAS Stacks

**Status:** Accepted  
**Date:** 2026-01-11  
**Author:** Codex (LLM agent)

## Context

NAS stacks are deployed via Docker Compose on non-Kubernetes nodes. Prior approaches relied on
naming conventions (e.g., numeric prefixes) to imply deployment order, which is fragile and
non-obvious. The repository now supports an explicit registry file (`stacks/registry.toml`) that
defines stack paths and dependencies, enabling deterministic ordering and clearer intent.

## Decision

1. **All NAS stacks MUST be listed in `stacks/registry.toml`.**
2. **Deployment order MUST be derived from registry dependencies**, not naming conventions.
3. **Unregistered stacks are invalid** and must not be deployed or introduced in PRs.

## Consequences

- Contributors must update `stacks/registry.toml` when adding or removing stacks.
- Deployment tooling can validate dependency ordering and detect cycles.
- Stack directory names are no longer tied to ordering conventions.

## Alternatives Considered

- **Numeric prefixes (00-/10-/20-)** — rejected; implicit and error-prone.
- **Free-form ordering in docs** — rejected; not machine-validated.

## References

- `stacks/registry.toml`
- `contracts/invariants.md`
- `requirements/workflow/repository-structure.md`
