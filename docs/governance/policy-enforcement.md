# Policy Enforcement Architecture

**Status:** Active  
**Effective:** 2025-12-20

## Purpose

This document explains how governance constraints defined in `constitution/`, `contracts/`, and `requirements/` are **machine-enforced** via Kyverno policies to prevent unsafe infrastructure changes.

## Problem Statement

### Before Policy Enforcement

Governance was **documented but not enforced**:
- Contracts said "MUST NOT deploy databases on Longhorn" → nothing stopped it
- Hard-stops said "MUST NOT expose services to WAN" → LoadBalancer with `externalIPs` would pass PR review
- Secrets spec said "MUST use 1Password/ESO" → inline secrets in YAML would merge

**Result:** AI agents (and humans) could violate constitutional principles accidentally or through optimization pressure.

### After Policy Enforcement

Governance is **encoded as admission control**:
- Kyverno policies **block** prohibited patterns at PR time (CI) and runtime (cluster admission webhooks)
- Invalid manifests **cannot merge** (CI fails)
- Invalid manifests **cannot deploy** (admission webhook denies)

## Three-Layer Defense Model

```
┌─────────────────────────────────────────────────────┐
│ Layer 1: Pre-Commit Hooks (Developer Workstation)  │
│ ├─ Secret scanning (gitleaks/trufflehog)           │
│ ├─ YAML lint (yamllint with custom rules)          │
│ └─ Basic schema validation (kubeval/kubeconform)   │
│                                                     │
│ Status: ⚠️  Recommended (not yet implemented)       │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ Layer 2: CI/CD Policy Checks (GitHub Actions)      │
│ ├─ Kyverno CLI validates policy syntax             │
│ ├─ Kyverno CLI applies policies to manifests       │
│ ├─ PR blocked if violations detected               │
│ └─ Policy test suite ensures policies work         │
│                                                     │
│ Status: ✅ Implemented (.github/workflows/)         │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│ Layer 3: Runtime Admission Control (Kubernetes)    │
│ ├─ Kyverno ClusterPolicies deployed to cluster     │
│ ├─ Admission webhooks enforce on apply             │
│ ├─ Audit mode logs violations without blocking     │
│ └─ PolicyReports for observability                 │
│                                                     │
│ Status: 📦 Policies defined (not yet deployed)      │
└─────────────────────────────────────────────────────┘
```

### Why Three Layers?

1. **Layer 1 (Pre-Commit):** Fastest feedback, catches mistakes before commit
2. **Layer 2 (CI):** Gate for PRs, prevents bad code from merging
3. **Layer 3 (Runtime):** Defense against manual `kubectl apply`, drift, or policy bypass

**Fail-Closed Principle:** If Layer 2 or 3 fail, the change is blocked. No "trust but verify."

## Policy Catalog

### Storage Domain ([`policies/storage/`](../policies/storage/))

| Policy | Failure Mode Prevented | Enforcement |
|--------|------------------------|-------------|
| [`deny-database-on-longhorn.yaml`](../policies/storage/deny-database-on-longhorn.yaml) | Data loss on node failure (Longhorn not ACID-compliant) | **Enforce** |
| [`enforce-longhorn-replicas.yaml`](../policies/storage/enforce-longhorn-replicas.yaml) | Single-node failure causes data unavailability | **Enforce** |
| [`restrict-rwx-access-mode.yaml`](../policies/storage/restrict-rwx-access-mode.yaml) | Undefined behavior with NFSv4 provisioner overlay | **Enforce** |
| [`limit-volume-size.yaml`](../policies/storage/limit-volume-size.yaml) | Cluster capacity exhaustion, large volumes on wrong storage | **Enforce (>1TB)** / **Audit (>500GB)** |

**Rationale:** [ADR-0010: Longhorn Storage](../adr/ADR-0010-longhorn-storage.md), [requirements/storage/spec.md](../../requirements/storage/spec.md)

### Ingress Domain ([`policies/ingress/`](../policies/ingress/))

| Policy | Failure Mode Prevented | Enforcement |
|--------|------------------------|-------------|
| [`deny-loadbalancer-external-ips.yaml`](../policies/ingress/deny-loadbalancer-external-ips.yaml) | WAN exposure bypassing Cloudflare Access | **Enforce** |
| [`deny-nodeport-services.yaml`](../policies/ingress/deny-nodeport-services.yaml) | WAN exposure via misconfigured firewall rules | **Enforce** |

**Rationale:** [ADR-0002: Tunnel-Only Ingress](../adr/ADR-0002-tunnel-only-ingress.md), [constitution: External Access is Identity-Gated](../../constitution/constitution.md)

### Secrets Domain ([`policies/secrets/`](../policies/secrets/))

| Policy | Failure Mode Prevented | Enforcement |
|--------|------------------------|-------------|
| [`deny-inline-secrets.yaml`](../policies/secrets/deny-inline-secrets.yaml) | Secret leakage in git, lack of rotation, credential sprawl | **Enforce** |

**Rationale:** [ADR-0004: Secrets Management](../adr/ADR-0004-secrets-management.md), [requirements/secrets/spec.md](../../requirements/secrets/spec.md)

### DNS Domain ([`policies/dns/`](../policies/dns/))

| Policy | Failure Mode Prevented | Enforcement |
|--------|------------------------|-------------|
| *(Not yet implemented)* | Split-horizon DNS bypassing Cloudflare Access | **Planned** |

**Rationale:** [ADR-0001: DNS Intent](../adr/ADR-0001-dns-intent.md), [requirements/dns/spec.md](../../requirements/dns/spec.md)

### Management Domain ([`policies/management/`](../policies/management/))

| Policy | Failure Mode Prevented | Enforcement |
|--------|------------------------|-------------|
| *(Not yet implemented)* | Overlay agents on management VLAN → network compromise | **Planned** |

**Rationale:** [ADR-0003: Management Network](../adr/ADR-0003-management-network.md)

### Repository Structure ([`policies/repository/`](../policies/repository/))

| Policy | Failure Mode Prevented | Enforcement |
|--------|------------------------|-------------|
| [`deny-unauthorized-root-files.rego`](../policies/repository/deny-unauthorized-root-files.rego) | Documentation sprawl, arbitrary summary files, unclear content ownership | **Enforce** (Conftest + OPA) |

**Rationale:** [requirements/workflow/repository-structure.md](../../requirements/workflow/repository-structure.md)

## Override Mechanism (Break-Glass)

**Policies are not immutable** — they can be overridden with explicit approval annotations.

### Example: Database on Longhorn (Prohibited)

**Default behavior:** Denied by `deny-database-on-longhorn.yaml`

**Override:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-test
  annotations:
    storage.hypyr.space/database-on-longhorn-approved: "true"
    storage.hypyr.space/approval-adr: "ADR-0042"  # Must reference an ADR
spec:
  volumeClaimTemplates:
  - spec:
      storageClassName: longhorn  # Now allowed with annotation
```

**Requirements for override:**
1. **Annotation present:** `<domain>.hypyr.space/<policy>-approved: "true"`
2. **ADR reference:** `<domain>.hypyr.space/approval-adr: "ADR-XXXX"`
3. **Documented justification:** ADR explains why exception is necessary
4. **Expiration plan:** ADR should include plan to remove exception

### Why Overrides Are Allowed

- **Break-glass scenarios:** Emergency fixes may require bypassing policy temporarily
- **Policy evolution:** Policies may be overly restrictive initially
- **Learning:** New patterns may emerge that require exceptions

**Overrides are audited** via PolicyReports and should be reviewed quarterly.

## CI/CD Integration

### GitHub Actions Workflow

**File:** [`.github/workflows/policy-enforcement.yml`](../../.github/workflows/policy-enforcement.yml)

**Triggers:**
- Pull requests modifying `infra/**/*.yaml` or `policies/**/*.yaml`
- Pushes to `main` branch

**Steps:**
1. **Install Kyverno CLI**
2. **Validate policy syntax** (`kyverno validate`)
3. **Find Kubernetes manifests** in `infra/` (exclude Kustomize/Flux metadata)
4. **Apply policies** to manifests (`kyverno apply`)
5. **Fail PR** if violations detected
6. **Post comment** to PR with violation details

**Exit codes:**
- `0`: All policies passed
- `1`: Policy violations detected (PR blocked)

### Local Validation

```bash
# Validate all policies and test manifests
task validate:policies

# Test only policy syntax
task validate:policies:syntax

# Test policies against test manifests
task test:policies
```

## Testing Strategy

### Test Manifests

**Location:** [`test/policies/`](../../test/policies/)

**Structure:**
```
test/policies/
├── storage/
│   ├── valid/          # Should PASS policies
│   └── invalid/        # Should FAIL policies
├── ingress/
│   ├── valid/
│   └── invalid/
└── secrets/
    ├── valid/
    └── invalid/
```

### Test Coverage

**Each policy MUST have:**
1. **At least one invalid test case** that triggers the policy
2. **At least one valid test case** that passes the policy
3. **Edge case tests** (if applicable)

### Running Tests

```bash
# All tests
task test:policies

# Expected output:
# ✓ policies/storage/deny-database-on-longhorn.yaml blocked invalid-postgres-longhorn.yaml
# ✓ policies/storage/deny-database-on-longhorn.yaml allowed valid-app-longhorn.yaml
# ✓ All policy tests passed
```

## Deployment

### Layer 2 (CI) Deployment

**Status:** ✅ Active

Policy enforcement in CI is **automatically enabled** for all PRs via GitHub Actions.

### Layer 3 (Runtime) Deployment

**Status:** 📦 Policies defined, not yet deployed

**Deployment method (planned):**
1. Install Kyverno via Flux HelmRelease or Kustomize
2. Deploy policies to cluster as Flux Kustomization
3. Configure PolicyReports monitoring
4. Set up alerts for policy violations

**Rollout strategy:**
1. **Phase 1:** Deploy policies in **Audit mode** (log only, no blocking)
2. **Phase 2:** Review PolicyReports, fix violations
3. **Phase 3:** Switch to **Enforce mode** (block violations)

## Observability

### Policy Reports

Kyverno generates `PolicyReport` and `ClusterPolicyReport` resources for each namespace and cluster-wide.

**Query policy violations:**
```bash
kubectl get policyreport -A
kubectl get clusterpolicyreport
```

**Example PolicyReport:**
```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: cpol-deny-database-on-longhorn
  namespace: database
results:
- policy: deny-database-on-longhorn
  rule: deny-database-statefulset-longhorn
  result: fail
  message: "Database workload 'postgres' is prohibited from using Longhorn storage"
  resource:
    kind: StatefulSet
    name: postgres
```

### Monitoring Integration

**Recommended:**
- Export PolicyReports to Prometheus (Kyverno exporter)
- Alert on `policy_result{result="fail"}`
- Dashboard for policy compliance percentage

## Failure Modes & Mitigation

### Policy Webhook Unavailable

**Failure Mode:** Kyverno webhook down → cluster admission fails  
**Mitigation:**
- Kyverno runs with 3 replicas (HA mode)
- `failurePolicy: Fail` (fail-closed: if webhook down, block everything)
- Alternative: `failurePolicy: Ignore` (fail-open: if webhook down, allow everything)

**Recommendation:** `Fail` for critical policies (WAN exposure, secrets), `Ignore` for lower-risk policies (volume size warnings)

### Policy Drift

**Failure Mode:** Policies updated but requirements not updated  
**Mitigation:**
- CI enforces that policy changes reference requirements or ADRs
- `scripts/adr-must-be-linked-from-spec.sh` ensures traceability

### False Positives

**Failure Mode:** Policy blocks valid use case  
**Mitigation:**
1. **Override annotation** for immediate unblock
2. **Open issue** to refine policy
3. **Update policy** to allow valid pattern
4. **Document in ADR** if exception becomes permanent

## Policy Development Workflow

### Adding a New Policy

1. **Identify governance gap** (e.g., "nothing prevents split-horizon DNS")
2. **Define constraint** in `requirements/**/spec.md` or `contracts/*.md`
3. **Create Kyverno policy** in `policies/<domain>/<policy-name>.yaml`
4. **Add test cases** in `test/policies/<domain>/invalid/` and `valid/`
5. **Run tests locally**: `task test:policies`
6. **Update requirements** to reference policy file
7. **Open PR** with policy + tests + requirement update
8. **CI validates** policy syntax and tests
9. **Merge** when approved
10. **Deploy to cluster** via Flux (Phase 3)

### Modifying Existing Policy

1. **Open issue** explaining problem (false positive, new use case, etc.)
2. **Update policy** YAML
3. **Update test cases** to cover new behavior
4. **Update requirements** if constraint changed
5. **Create ADR** if policy change is significant
6. **Run tests**: `task test:policies`
7. **Open PR** with changes
8. **Redeploy** to cluster (if Layer 3 active)

### Deprecating a Policy

1. **Open issue** with justification
2. **Create ADR** explaining why policy no longer needed
3. **Switch to Audit mode** (if deployed to cluster)
4. **Monitor for violations** for 30 days
5. **Remove policy** if no violations
6. **Update requirements** to remove reference

## References

- **Constitution:** [constitution/constitution.md](../../constitution/constitution.md)
- **Hard-Stops:** [contracts/hard-stops.md](../../contracts/hard-stops.md)
- **Invariants:** [contracts/invariants.md](../../contracts/invariants.md)
- **Requirements:** [requirements/](../../requirements/)
- **ADRs:** [docs/adr/](../adr/)
- **Kyverno Documentation:** https://kyverno.io/docs/
- **Kubernetes Policy Working Group:** https://github.com/kubernetes-sigs/wg-policy-prototypes
