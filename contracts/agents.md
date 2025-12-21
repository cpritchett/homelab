# Agent Operating Rules
**Effective:** 2025-12-14  
**Updated:** 2025-12-20 (Policy enforcement)

This file defines **agent operating rules** for this repo.

Agents must comply with all files in `contracts/` and `requirements/`.

## Allowed actions
Agents MAY:
- Propose changes as PR-ready patches
- Add ADRs and update docs to explain changes
- Add checklists, runbooks, and templates
- Add placeholders under `infra/` and `ops/` while the repo is being bootstrapped
- Add policy override annotations IF accompanied by:
  - Justification annotation explaining why
  - ADR documenting the exception
  - Expiration plan or trigger for removal

## Prohibited actions
Agents MUST NOT:
- Make changes that violate `requirements/` or `contracts/invariants.md`
- "Simplify" boundaries by collapsing zones, networks, or responsibilities
- Assume BGP, routing policy, or VLAN changes are acceptable without an explicit ADR
- Add policy override annotations without justification + ADR reference
- Modify Kyverno policies to weaken enforcement without documented rationale
- Create arbitrary files in repository root (only approved files allowed, see below)
- Create summary documents or change logs outside of `docs/`, `docs/adr/`, or `ops/`
- Install tools via brew/curl in scripts (use mise: `.mise.toml`)
- Write imperative validation scripts when Conftest/Kyverno policy is appropriate

## Policy enforcement awareness

Agents MUST be aware that **machine-enforceable policies** exist:

### Enforcement points
1. **CI (Layer 2):** `.github/workflows/policy-enforcement.yml` blocks PRs with policy violations
2. **Runtime (Layer 3):** Kyverno admission webhooks block invalid manifests at apply time (when deployed)

### Policy domains
- **Storage:** [`policies/storage/`](../policies/storage/) — databases on Longhorn, RWX, volume sizes, replica counts
- **Ingress:** [`policies/ingress/`](../policies/ingress/) — LoadBalancer/NodePort, externalIPs, WAN exposure
- **Secrets:** [`policies/secrets/`](../policies/secrets/) — inline secrets, ESO requirement
- **DNS:** [`policies/dns/`](../policies/dns/) — split-horizon prohibition (planned)
- **Management:** [`policies/management/`](../policies/management/) — overlay agent prohibition (planned)

### When proposing changes
1. **Check requirements first:** `requirements/<domain>/spec.md` defines allowed patterns
2. **Verify policy compliance:** `task validate:policies` before opening PR
3. **Use override annotations correctly:** Include justification + ADR reference if needed
4. **Explain in PR description:** Why change is safe / complies with policies

### Policy override example

If a change would violate a policy but is justified:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: large-cache
  annotations:
    storage.hypyr.space/rwx-approved: "true"
    storage.hypyr.space/rwx-justification: "Shared cache for distributed build system"
    storage.hypyr.space/approval-adr: "ADR-0042"
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: longhorn
```

**ADR-0042 must exist** and explain:
- Why RWX on Longhorn is acceptable for this workload
- What failure modes are understood and acceptable
- Plan to migrate to TrueNAS if workload grows

## Repository structure constraints

### Allowed root-level files (exhaustive)
- `README.md` — Repository overview (router only)
- `CONTRIBUTING.md` — Contribution guidelines
- `CLAUDE.md` — Claude-specific instructions (router only)
- `Taskfile.yml` — Task definitions
- `agents.md` — Agent operating rules (router only)
- `.gitignore`, `.mise.toml` — Tool configuration

### Allowed root-level directories
- `constitution/`, `contracts/`, `requirements/` — Governance
- `docs/` — Documentation (including ADRs)
- `infra/` — Infrastructure as code
- `ops/` — Operational documentation (runbooks, changelogs)
- `policies/` — Kyverno policies
- `scripts/` — CI/validation scripts
- `test/` — Test manifests
- `.github/`, `.claude/`, `.gemini/`, `.specify/`, `.vscode/` — Tooling

### Where to put things

| Content Type | Location | Example |
|--------------|----------|----------|
| Architecture decision | `docs/adr/` | `ADR-0011-new-decision.md` |
| General documentation | `docs/` | `docs/policy-enforcement.md` |
| Operational runbook | `ops/runbooks/` | `ops/runbooks/restore-backup.md` |
| Change log | `ops/CHANGELOG.md` | Single file, append-only |
| Implementation details | `infra/<domain>/` | `infra/storage/longhorn-config.yaml` |
| Test cases | `test/<domain>/` | `test/policies/storage/invalid/` |

**Enforcement:** OPA/Rego policy [`policies/repository/deny-unauthorized-root-files.rego`](../policies/repository/deny-unauthorized-root-files.rego)  
**Specification:** [requirements/workflow/repository-structure.md](../requirements/workflow/repository-structure.md)  
**CI Check:** `.github/workflows/guardrails.yml` → `scripts/enforce-root-structure.sh` → Conftest

## References

- **Policy Architecture:** [docs/policy-enforcement.md](../docs/policy-enforcement.md)
- **Policy Catalog:** [policies/README.md](../policies/README.md)
- **Constitution:** [constitution/constitution.md](../constitution/constitution.md)
- **Hard-Stops:** [contracts/hard-stops.md](hard-stops.md)
- **Invariants:** [contracts/invariants.md](invariants.md)
