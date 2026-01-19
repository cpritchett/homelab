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
| `bootstrap/` | Bootstrap assets and Helmfile scaffolding | Infrastructure |
| `requirements/` | Domain requirements and checks | Governance |
| `docs/` | Documentation (including ADRs) | Documentation |
| `infra/` | Infrastructure as code | Implementation |
| `kubernetes/` | GitOps manifests and cluster overlays | Implementation |
| `stacks/` | NAS deployment manifests (Docker Compose, systemd) | Implementation |
| `ops/` | Operational docs (runbooks, changelogs) | Operations |
| `policies/` | Kyverno admission policies | Policy |
| `scripts/` | CI/validation scripts | Tooling |
| `talos/` | Talos node configuration templates and values | Infrastructure |
| `test/` | Test manifests for policies | Testing |
| `.github/` | GitHub Actions, templates | Tooling |
| `.claude/` | Claude Code configuration | Tooling |
| `.gemini/` | Gemini configuration | Tooling |
| `.specify/` | Specify configuration | Tooling |
| `.vscode/` | VS Code workspace config | Tooling |

## Prohibited patterns

1. **No arbitrary root-level markdown files**
   - Summary documents → `docs/`
   - Change logs → `ops/CHANGELOG.md` (single file)
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
| Runbook | `ops/runbooks/*.md` | Operational procedures |
| Change log | `ops/CHANGELOG.md` | Single file, append-only |
| Policy definition | `policies/<domain>/*.yaml` | Kyverno ClusterPolicy YAML |
| Infrastructure config | `infra/<domain>/` | Kubernetes manifests, configs |
| GitOps manifests | `kubernetes/` | Flux sources, cluster overlays, app stacks |
| NAS deployment manifests | `stacks/` | Docker Compose, systemd units for non-K8s nodes |
| Bootstrap manifests | `bootstrap/` | Bootstrap resources/Helmfile scaffolding |
| Test case | `test/<domain>/` | Test manifests, fixtures |
| Ongoing scripts | `scripts/*.sh` | CI validation, reusable tools, maintained indefinitely |
| One-shot scripts | `scripts/one-shot/YYYY-MM-DD-purpose/` | Temporary, dated, single-purpose with README.md |

## NAS stacks registry

- All NAS stacks MUST be registered in `stacks/registry.conf`.
- Deployment order MUST be derived from registry dependencies (no ordering by naming).

## Script Organization

**Ongoing Scripts** (`scripts/`):
- CI validation scripts (gates, checks)
- Reusable automation tools  
- Infrastructure maintenance scripts
- Must be maintained and kept current
- Examples: `run-all-gates.sh`, `check-kustomize-build.sh`

**One-Shot Scripts** (`scripts/one-shot/YYYY-MM-DD-purpose/`):
- Temporary scripts for specific tasks
- Migration scripts, cleanup scripts, emergency fixes
- Must be dated (ISO 8601: YYYY-MM-DD) and single-purpose
- Each directory MUST contain README.md with purpose, context, usage, and completion status
- Examples: `scripts/one-shot/2025-01-17-harbor-legacy-cleanup/`

**Documentation Requirements**:
- **Ongoing scripts** MUST include comprehensive header comments and entry in `scripts/README.md`
- **Complex ongoing scripts** (>50 lines) MUST include individual README.md files
- **One-shot scripts** MUST include README.md in directory with context and completion criteria

**Prohibited**:
- Scripts outside `scripts/` or `scripts/one-shot/`
- One-shot scripts directly in `scripts/`
- One-shot directories without dates or README.md
- Ongoing scripts without proper documentation

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
- **Policy Enforcement:** [docs/governance/policy-enforcement.md](../../docs/governance/policy-enforcement.md)
- **ADR-0020:** [Bootstrap, Storage, Repository Governance, and NAS Stacks Codification](../../docs/adr/ADR-0020-bootstrap-storage-governance-codification.md)
- **ADR-0021:** [Require Registry for NAS Stacks](../../docs/adr/ADR-0021-stacks-registry-required.md)
- **ADR-0022:** [Explicit Stack Ordering with Order Fields](../../docs/adr/ADR-0022-explicit-stack-ordering.md)
- **ADR-0023:** [Script Organization Requirements](../../docs/adr/ADR-0023-script-organization-requirements.md)
