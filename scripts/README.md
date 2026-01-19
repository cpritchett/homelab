# Scripts Documentation

This directory contains ongoing scripts for CI validation, infrastructure maintenance, and reusable automation tools.

## Quick Reference

| Script | Purpose | Usage | Maintainer |
|--------|---------|-------|------------|
| `run-all-gates.sh` | Execute all CI gates locally | `./run-all-gates.sh "PR title" "description"` | Governance |
| `no-invariant-drift.sh` | Check router files for hardcoded values | Called by CI/gates | Governance |
| `require-adr-on-canonical-changes.sh` | Enforce ADR requirement for canonical changes | Called by CI/gates | Governance |
| `adr-must-be-linked-from-spec.sh` | Ensure ADRs are linked from specs | Called by CI/gates | Governance |
| `check-kustomize-build.sh` | Validate Flux Kustomizations build | Called by CI/gates | Infrastructure |
| `check-helmrelease-template.sh` | Validate HelmReleases render | Called by CI/gates | Infrastructure |
| `check-no-plaintext-secrets.sh` | Detect plaintext Kubernetes secrets | Called by CI/gates | Security |
| `check-deprecated-apis.sh` | Find deprecated K8s API versions | Called by CI/gates | Infrastructure |
| `check-talos-ytt-render.sh` | Validate Talos configs render | Called by CI/gates | Infrastructure |
| `check-cross-env-refs.sh` | Prevent cross-environment references | Called by CI/gates | Infrastructure |
| `check-crd-ordering.sh` | Validate CRD/CR ordering | Called by CI/gates | Infrastructure |
| `enforce-root-structure.sh` | Validate repository root structure | Called by CI/gates | Governance |
| `security-test.sh` | Security validation tests | Called by CI | Security |
| `test-talos-templates.sh` | Local Talos template validation | Manual/CI | Infrastructure |

## CI Validation Scripts

### run-all-gates.sh
**Purpose:** Master script that executes all CI gates locally for comprehensive validation  
**Usage:** `./scripts/run-all-gates.sh "PR title" "PR description"`  
**Dependencies:** All individual gate scripts  
**Maintained by:** Governance team  
**Notes:** Use this for local validation before pushing changes

### Gate Scripts

#### no-invariant-drift.sh
**Purpose:** Ensure router files (README.md, agents.md, etc.) don't contain hardcoded invariant values  
**Usage:** Called automatically by run-all-gates.sh or CI  
**Dependencies:** grep, basic shell utilities  
**Maintained by:** Governance team  

#### require-adr-on-canonical-changes.sh
**Purpose:** Enforce ADR requirement when canonical files (constitution/, contracts/, requirements/) are modified  
**Usage:** Called automatically by CI  
**Dependencies:** git, environment variables (GITHUB_BASE_REF, PR_TITLE, PR_BODY)  
**Maintained by:** Governance team  

#### adr-must-be-linked-from-spec.sh
**Purpose:** Ensure new/modified ADRs are properly linked from relevant specification files  
**Usage:** Called automatically by CI  
**Dependencies:** git, grep  
**Maintained by:** Governance team  

## Infrastructure Validation Scripts

#### check-kustomize-build.sh
**Purpose:** Validate all Flux Kustomizations build successfully without errors  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** kustomize binary  
**Maintained by:** Infrastructure team  
**Notes:** Skips remote resources by default; set SKIP_REMOTE=0 to include

#### check-helmrelease-template.sh
**Purpose:** Validate HelmReleases can be templated (best-effort offline rendering)  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** helm binary  
**Maintained by:** Infrastructure team  
**Notes:** May require chart repositories to be added locally

#### check-talos-ytt-render.sh
**Purpose:** Validate Talos machine configurations render from ytt templates without missing values  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** ytt binary, Talos templates  
**Maintained by:** Infrastructure team  

#### check-deprecated-apis.sh
**Purpose:** Detect removed or deprecated Kubernetes API versions in manifests  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** grep, knowledge of deprecated APIs  
**Maintained by:** Infrastructure team  

#### check-cross-env-refs.sh
**Purpose:** Prevent Flux sources and Kustomizations from referencing paths across clusters/environments  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** grep, yaml parsing  
**Maintained by:** Infrastructure team  

#### check-crd-ordering.sh
**Purpose:** Validate CRDs/controllers reconcile before CR instances (ordering validation)  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** yaml parsing, Kubernetes knowledge  
**Maintained by:** Infrastructure team  

## Security Scripts

#### check-no-plaintext-secrets.sh
**Purpose:** Detect plaintext Kubernetes Secret manifests (SOPS-encrypted allowed)  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** grep, yaml parsing  
**Maintained by:** Security team  
**Notes:** Allows bootstrap placeholders and SOPS-encrypted secrets

#### security-test.sh
**Purpose:** Additional security validation tests  
**Usage:** Called by CI or manual execution  
**Dependencies:** Various security tools  
**Maintained by:** Security team  

## Repository Structure Scripts

#### enforce-root-structure.sh
**Purpose:** Validate repository root structure against allowed files/directories  
**Usage:** Called by run-all-gates.sh or standalone  
**Dependencies:** Basic shell utilities  
**Maintained by:** Governance team  
**Notes:** Exhaustively enumerates allowed root-level items

## Development Scripts

#### test-talos-templates.sh
**Purpose:** Local Talos template validation (mirrors CI behavior)  
**Usage:** `./scripts/test-talos-templates.sh`  
**Dependencies:** ytt, Talos configuration files  
**Maintained by:** Infrastructure team  
**Notes:** Useful for local development and debugging

## Adding New Scripts

When adding new ongoing scripts:

1. **Include comprehensive header comment** with purpose, usage, dependencies, maintainer
2. **Add entry to this README.md** in appropriate section
3. **Create individual README.md** if script is complex (>50 lines)
4. **Follow naming conventions** - use kebab-case, descriptive names
5. **Make executable** - `chmod +x script-name.sh`
6. **Test thoroughly** before committing

## One-Shot Scripts

For temporary scripts, use `scripts/one-shot/YYYY-MM-DD-purpose/` structure.  
See [ADR-0023](../docs/adr/ADR-0023-script-organization-requirements.md) for details.

## Related Documentation

- **Script Organization:** [ADR-0023](../docs/adr/ADR-0023-script-organization-requirements.md)
- **Repository Structure:** [requirements/workflow/repository-structure.md](../requirements/workflow/repository-structure.md)
- **CI Gates:** [docs/governance/ci-gates.md](../docs/governance/ci-gates.md)
- **Invariants:** [contracts/invariants.md](../contracts/invariants.md)