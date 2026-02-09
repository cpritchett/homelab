---
name: Common Commands
description: Essential commands for working in this repository
invokable: true
---

**Development Tools:**
```bash
# Install tools (required first time)
mise install

# List available tasks
mise run --list
```

**CI & Validation:**
```bash
# Run all CI gates (MUST pass before completing work)
./scripts/run-all-gates.sh "PR title with ADR reference" "PR description"

# Run individual gates
./scripts/no-invariant-drift.sh
./scripts/require-adr-on-canonical-changes.sh
./scripts/adr-must-be-linked-from-spec.sh
```

**Security:**
```bash
# Security scan for secrets
gitleaks detect --source . --verbose --config .gitleaks.toml

# Staged check (run by git hooks)
gitleaks protect --staged --redact
```

**Kubernetes & Infrastructure:**
```bash
# Check Kustomize builds
./scripts/check-kustomize-build.sh

# Validate HelmRelease templates
./scripts/check-helmrelease-template.sh

# Check CRD ordering
./scripts/check-crd-ordering.sh
```

**Spec-Kit Workflow (for non-canonical work):**
See `.specify/README.md` for `/speckit.*` commands and governance-driven development.

See `Taskfile.yml` and individual script files for additional options.
