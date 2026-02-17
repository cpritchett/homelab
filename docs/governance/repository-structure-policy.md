# Repository Structure Policy
**Domain:** Repository Governance  
**Effective:** 2025-12-20

## Intent

Repository root structure is **fixed and enumerated** to prevent:
- Documentation sprawl (arbitrary summary files)
- Tool/IDE configuration drift
- Unclear ownership of content

## Allowed root-level files

| File | Purpose | Owner |
|------|---------|-------|
| `README.md` | Repository overview (router only) | Governance |
| `CONTRIBUTING.md` | Contribution guidelines | Governance |
| `CLAUDE.md` | Claude-specific instructions (router) | Governance |
| `Taskfile.yml` | Task definitions | Tooling |
| `agents.md` | Agent operating rules (router) | Governance |
| `.gitignore` | Git exclusions | Tooling |
| `.mise.toml` | Mise tool versions | Tooling |

## Allowed root-level directories

| Directory | Purpose | Owner |
|-----------|---------|-------|
| `constitution/` | Immutable principles | Governance |
| `contracts/` | Hard-stops, invariants, agent rules | Governance |
| `requirements/` | Domain requirements and checks | Governance |
| `docs/` | Documentation (ADRs, architecture, runbooks) | Documentation |
| `stacks/` | Docker Swarm/Compose deployment manifests | Implementation |
| `ansible/` | Node configuration and hardening playbooks | Implementation |
| `opentofu/` | Proxmox VM provisioning | Implementation |
| `komodo/` | Komodo ResourceSync declarative config | Implementation |
| `ops/` | Operational artifacts (runbooks moved to docs/runbooks/) | Operations |
| `policies/` | OPA Rego admission policies | Policy |
| `scripts/` | CI/validation scripts | Tooling |
| `specs/` | Non-canonical specs and design docs (speckit outputs) | Governance |
| `.github/` | GitHub Actions, templates | Tooling |
| `.claude/` | Claude Code configuration | Tooling |
| `.gemini/` | Gemini configuration | Tooling |
| `.specify/` | Specify configuration | Tooling |
| `.vscode/` | VS Code workspace config | Tooling |

## Prohibited patterns

1. **No arbitrary root-level markdown files**
   - Summary documents → `docs/`
   - Change logs → use conventional commits and release-please
   - ADRs → `docs/adr/`

2. **No temporary/scratch files in root**
   - No `NOTES.md`, `TODO.md`, `SUMMARY.md`, etc.
   - No `*-improvements.md`, `*-summary.md` patterns

3. **No tool-specific configs outside hidden dirs**
   - `.prettierrc`, `.eslintrc` → Only if project uses them
   - IDE configs → `.vscode/`, `.idea/` (hidden dirs only)

## Content placement rules

| Content Type | Required Location | Notes |
|--------------|-------------------|-------|
| Architecture decision | `docs/adr/ADR-NNNN-*.md` | Numbered, immutable after merge |
| Technical documentation | `docs/*.md` | General purpose docs |
| Architecture documentation | `docs/architecture/*.md` | System architecture with diagrams |
| Deployment/operational guide | `docs/guides/*.md` | Bootstrap, platform deployment, service-specific guides |
| Convention reference | `docs/reference/*.md` | Label patterns, permissions, Renovate config |
| Known issue / troubleshooting | `docs/troubleshooting/*.md` | Reactive issue documentation and fixes |
| Runbook | `docs/runbooks/*.md` | Operational procedures |
| Canonical spec | `requirements/<domain>/spec.md` | One per domain |
| Non-canonical spec | `specs/NNN-<slug>/spec.md` | speckit outputs, archived as needed |
| Policy definition | `policies/<domain>/*.rego` | OPA Rego policies |
| Deployment manifests | `stacks/` | Docker Compose for Swarm/Compose stacks |
| Node configuration | `ansible/` | Ansible playbooks and roles |
| VM provisioning | `opentofu/` | OpenTofu Proxmox provider |
| Komodo resources | `komodo/resources.toml` | Declarative stack definitions |
| CI script | `scripts/*.sh` | Validation scripts |

## NAS stacks deployment

- NAS stacks are deployed via TrueNAS Komodo using per-stack Compose definitions under `stacks/`.
- No registry file is used; any cross-stack dependency must be documented in stack docs.

## Enforcement

**Method:** Conftest + OPA Rego policy

**Policy location:** `policies/repository/deny-unauthorized-root-files.rego`

**CI validation:** `.github/workflows/guardrails.yml`

**Local validation:** `task validate:structure`

## Rationale

**Problem:** AI agents create arbitrary summary documents in root (`GOVERNANCE-IMPROVEMENTS.md`, `IMPLEMENTATION-SUMMARY.md`) leading to:
- Unclear canonical location for content
- Documentation sprawl
- Maintenance burden (which summaries are current?)

**Solution:** Exhaustively enumerate allowed root files + policy enforcement

**Why not rely on convention?** Agents optimize for "helpful" behavior (creating summaries) without understanding repository ownership model.

## References

- **Invariants:** [contracts/invariants.md](../../contracts/invariants.md#repository-structure-invariants)
- **Agent Rules:** [contracts/agents.md](../../contracts/agents.md#repository-structure-constraints)
- **ADR-0020:** [Bootstrap, Storage, Repository Governance, and NAS Stacks Codification](../../docs/adr/ADR-0020-bootstrap-storage-governance-codification.md)
- **ADR-0022:** [Komodo-Managed NAS Stacks](../../docs/adr/ADR-0022-truenas-komodo-stacks.md)
- **ADR-0037:** [Documentation Consolidation](../../docs/adr/ADR-0037-documentation-consolidation.md)
