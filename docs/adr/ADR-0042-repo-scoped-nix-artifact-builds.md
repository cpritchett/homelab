# ADR-0042: Repo-Scoped Nix Artifact Builds

**Status:** Accepted  
**Date:** 2026-03-14  
**Deciders:** Repository maintainers

## Context

This repository now contains Nix-based host definitions and generated netboot artifacts for the `broadside` recovery node.

The immediate use case is Broadside PXE bootstrapping:

- the host configuration is expressed as a flake output
- the installer bundle is generated from pinned flake inputs
- barbary's PXE stack must serve the generated artifacts

The existing tooling requirements standardize Task, mise, ytt, and policy tooling, but they do not yet describe when Nix is allowed or how it should be used in CI and deployment-adjacent workflows.

Without an explicit rule, Nix usage would be ambiguous:

- operators might assume system-wide Nix installation is required
- GitHub Actions would have no governed pattern for validating or building flake-backed artifacts
- generated PXE assets could drift away from the checked-in repo state

## Decision

The repository permits **repo-scoped Nix operations** for deterministic host definitions and generated artifacts, under these rules:

1. **Scope is narrow and explicit.**
   - Nix is allowed for host definitions, installer/netboot artifacts, and validation of pinned flake outputs.
   - Nix is not adopted as the repository's universal package manager or general deployment runtime.

2. **Global workstation installation is optional.**
   - Workflows MUST provide a repo-local or containerized path for running Nix.
   - Contributors and agents MUST NOT require system-wide Nix installation to participate in normal repository work.

3. **Pinned inputs are mandatory.**
   - Flake inputs MUST be locked.
   - Generated artifacts MUST come from the checked-in repo snapshot and locked inputs used for that build.

4. **Generated artifacts stay out of git unless explicitly required.**
   - Netboot bundles and similar build outputs are generated into ignored paths.
   - Git tracks the source configuration and the served asset directories, not the binary payloads.

5. **GitHub Actions may validate and build repo-scoped Nix artifacts.**
   - CI may run flake evaluation or artifact builds when triggered by relevant changes.
   - CI should upload generated outputs as artifacts for review rather than commit them back into the repository.

6. **Deployment ownership remains unchanged.**
   - Nix artifact generation supports existing deployment mechanisms.
   - It does not bypass governance, Komodo policy, or infrastructure tier boundaries.

## Consequences

### Positive

- Broadside PXE assets can be generated directly from the same repo revision that defines the host.
- Future Nix-backed recovery or installer workflows have a clear governance path.
- GitHub Actions can validate Nix outputs without forcing developers to install Nix globally.

### Negative

- CI and pre-deploy hooks gain another build tool to maintain.
- Some workflows become slower because they build deterministic artifacts rather than assuming prebuilt files.

### Neutral

- This does not change constitutional, DNS, ingress, or management boundaries.
- This does not turn the repo into a fully Nix-managed mono-platform.

## Implementation Notes

- Use repo scripts as the preferred entrypoint for Nix-backed tasks.
- Prefer containerized Nix helpers when native Nix is absent.
- Serve generated PXE assets from repo-local ignored directories on barbary so the checked-out repo remains the source of truth.

## Links

- [Tooling Requirements](../../requirements/tooling/spec.md)
- [Broadside Recovery Runbook](../runbooks/broadside-recovery.md)
