# GitHub Copilot Instructions (Router)

Keep this file short to prevent drift.

## Canonical sources (read these first)
- Constitution: `constitution/constitution.md`
- Hard-stops: `contracts/hard-stops.md`
- Invariants: `contracts/invariants.md`
- Agent rules: `contracts/agents.md`
- Domain specs: `requirements/**/spec.md`
- Checks: `requirements/**/checks.md`

## Governance procedures (read before making changes)
- Agent contract: `docs/governance/agent-contract.md` - MUST follow strictly
- CI gates: `docs/governance/ci-gates.md` - ALL must pass before completing
- Procedures: `docs/governance/procedures.md` - Required workflows

## Conflict rule
If anything conflicts, the order above wins. `docs/` is explanatory only.

## Repository Overview
This is a homelab infrastructure repository using GitOps principles with Kubernetes, Flux, Talos Linux, and strict governance controls.

### Key Directories
- `constitution/` - Immutable principles (highest authority)
- `contracts/` - Operating rules and invariants
- `requirements/` - Domain specifications (DNS, ingress, compute, storage, etc.)
- `kubernetes/` - Kubernetes manifests and Flux configs
- `talos/` - Talos Linux configurations
- `infra/` - Infrastructure implementation
- `ops/` - Operational tooling
- `docs/` - Explanatory documentation (non-normative)
- `scripts/` - CI gates and validation scripts

### Essential Tools (via mise)
Install tools: `mise install`
- `kubectl` - Kubernetes CLI
- `flux2` - GitOps toolkit
- `helm` - Kubernetes package manager
- `kustomize` - Kubernetes configuration management
- `talosctl` - Talos Linux CLI
- `task` - Task runner
- `gitleaks` - Secret scanning
- `conftest` - Policy testing
- `kyverno` - Policy validation

### Common Commands
```bash
# Install all tools
mise install

# Install git hooks
mise run hooks:install

# Run security scan on staged changes
mise run security:scan:staged

# Full repository security scan
mise run security:scan:repo

# Run all CI gates
./scripts/run-all-gates.sh "PR title" "PR description"

# Show available tasks
task --list

# Bootstrap local development
task bootstrap
```

## Build, Lint, and Test
This repository uses validation scripts instead of traditional unit tests:

### Validation Gates (must all pass)
```bash
# Run all gates together
./scripts/run-all-gates.sh "PR title" "PR body"

# Individual gates
./scripts/no-invariant-drift.sh              # Verify no drift in router files
./scripts/require-adr-on-canonical-changes.sh # ADR required for canonical changes
./scripts/adr-must-be-linked-from-spec.sh    # ADRs must be linked from specs
./scripts/check-helmrelease-template.sh      # Validate HelmRelease renders
./scripts/check-kustomize-build.sh           # Validate Kustomization builds
./scripts/check-cross-env-refs.sh            # Prevent cross-environment leakage
./scripts/check-crd-ordering.sh              # Verify CRD ordering
./scripts/check-talos-ytt-render.sh          # Validate Talos configs render
./scripts/check-no-plaintext-secrets.sh      # No plaintext secrets
./scripts/enforce-root-structure.sh          # Enforce directory structure
```

### Security Scanning
```bash
# Before committing (automatic via git hooks)
gitleaks protect --staged --redact --config .gitleaks.toml

# Full repository scan
gitleaks detect --source . --verbose --config .gitleaks.toml
```

## Coding Conventions

### Git Workflow
- Branch naming: `<type>/<scope>/<short-description>`
- Commit messages: Conventional Commits format
- Types: `feat`, `fix`, `docs`, `chore`
- Scopes: `dns`, `ingress`, `compute`, `tooling`, `governance`, `adr`, etc.
- Example: `feat(dns): add ExternalDNS internal/external policy support`
- See: `CONTRIBUTING.md` for full details

### YAML Style
- Use 2 spaces for indentation
- Follow Kubernetes YAML conventions
- Use `---` document separators
- Keep files under 500 lines when possible

### Documentation
- Use markdown for all docs
- Link to canonical sources, don't duplicate
- ADRs are append-only in `docs/adr/`
- Follow MADR format for ADRs

### Security Requirements
- NEVER commit secrets or credentials
- Always run `gitleaks` before finalizing changes
- Use 1Password integration for secret management
- Follow zero-trust networking principles

## Restrictions and Hard Rules

### DO NOT:
1. Weaken or bypass governance gates
2. Skip required ADRs for canonical changes
3. Restate invariants in router files (this file, README.md, agents.md, CLAUDE.md)
4. Violate constitutional principles (see `constitution/constitution.md`)
5. Commit secrets or credentials
6. Simplify away security boundaries (zones, networks, access controls)
7. Make network/BGP/routing changes without ADR and human review
8. Violate hard-stop conditions (see `contracts/hard-stops.md`)

### ALWAYS:
1. Read canonical sources before making changes
2. Run ALL gates before completing: `./scripts/run-all-gates.sh`
3. Create ADR for canonical changes (constitution/contracts/requirements/)
4. Link ADR from relevant spec
5. Follow conventional commit format
6. Run security scans before committing
7. Provide evidence in PR description
8. Respect the hierarchy of authority (constitution > contracts > requirements > docs)

## Before completing any change
1. Run all CI gates locally: `./scripts/run-all-gates.sh "PR title" "PR body"`
2. Create ADR if canonical change (constitution/contracts/requirements/)
3. Link ADR from relevant spec
4. Provide evidence in PR description
5. Run security scan: `gitleaks detect --source . --verbose`

## When Stuck or Uncertain
- Check canonical sources first (constitution, contracts, requirements)
- Review existing ADRs in `docs/adr/` for precedent
- Consult `docs/governance/procedures.md` for workflows
- Open an issue with `question` label if clarification needed
