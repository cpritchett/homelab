# ADR-0022: Komodo-Managed NAS Stacks (Supersedes ADR-0021)

**Status:** Accepted  
**Date:** 2026-01-19  
**Author:** Codex (LLM agent)  
**Supersedes:** [ADR-0021: Require Registry for NAS Stacks](./ADR-0021-stacks-registry-required.md)

## Context

- NAS stacks were previously deployed via host-side scripts (`sync-and-deploy`, `deploy-all`) that consumed `stacks/registry.toml` to enforce ordering and used 1Password CLI templating for secrets.
- Those scripts and the Harbor stack have been removed; remaining stacks (`proxy`, `authentik`) are packaged as plain Compose apps with `<item-name>.env.example` files.
- TrueNAS SCALE now ships the **Komodo** app for managing Docker Compose workloads directly from Git repositories, with built-in handling for environment variables and secrets. This makes the registry file and shell-based rollout tooling redundant.
- Continuing to require a registry and op-cli templating would add operational overhead without delivering value for the new, slimmer stack set.

## Decision

1. **TrueNAS Komodo is the authoritative deployment mechanism for NAS stacks.** Operators deploy each stack from this repository via the Komodo GitHub integration instead of host-side scripts.
2. **The stack registry (`stacks/registry.toml`) is retired.** Deployment ordering is handled per-stack inside Komodo; any cross-stack dependency (e.g., shared external network `proxy_network`) must be documented in stack docs rather than encoded in a registry file.
3. **Stacks must be Komodo-compatible and self-contained.** Each `stacks/<name>/compose.yml` plus one or more `<item-name>.env.example` files declares everything required for deployment; no `render-env.sh`, `op-inject`, or cron/init wrappers are used. Each `.env.example` file corresponds to one 1Password item.
4. **Secrets are supplied through Komodo, not 1Password CLI templates.** Each `<item-name>.env.example` file documents required variables for one 1Password item; actual values are entered through Komodo's env/secret fields or exported via the `op-export` stack.

## Consequences

### Positive

- Simpler operator workflow (UI-driven deploy/updates in TrueNAS).
- Eliminates brittle registry ordering logic and sparse-checkout scripts.
- Removes 1Password CLI dependency from NAS hosts while keeping secrets out of git.
- Stack directories remain small and focused on Compose definitions.

### Negative / Tradeoffs

- No automatic registry-based dependency ordering; operators must ensure prerequisites like `proxy_network` exist before deploying dependent stacks.
- Komodo availability is now a prerequisite for stack changes.
- Env/secret values are populated per 1Password item (each `<item-name>.env.example` documents required keys for one item).

## Alternatives Considered

- **Keep registry + host scripts** — rejected; higher complexity and no longer aligned with Komodo-based flow.
- **Move stacks to Flux/Kubernetes** — rejected; these workloads are intentionally NAS-local and lighter-weight than cluster apps.
- **Use custom Ansible/Taskfile deploys** — rejected; duplicates Komodo capabilities without added benefit.

## References

- ../../docs/governance/repository-structure-policy.md
- ../../requirements/workflow/spec.md
- ../STACKS.md
