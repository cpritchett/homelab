# Policy Enforcement (Kyverno)

This directory contains **Kyverno ClusterPolicy** definitions that enforce governance constraints defined in `constitution/` and `requirements/`.

## Purpose

These policies provide **machine-enforceable guardrails** to prevent:
- Storage misuse (databases on Longhorn, oversized volumes, RWX without approval)
- Ingress violations (WAN exposure, bypassing Cloudflare Tunnel)
- Secrets leakage (inline secrets instead of ESO references)
- DNS zone separation violations (split-horizon, public FQDNs in internal zone)
- Management network compromise (overlay agents on management VLAN)

## Structure

```
policies/
├── storage/
│   ├── deny-database-on-longhorn.yaml
│   ├── enforce-longhorn-replicas.yaml
│   ├── restrict-rwx-access-mode.yaml
│   └── limit-volume-size.yaml
├── ingress/
│   ├── deny-loadbalancer-external-ips.yaml
│   ├── deny-nodeport-services.yaml
│   └── require-cloudflare-tunnel.yaml
├── secrets/
│   ├── deny-inline-secrets.yaml
│   └── require-external-secrets-operator.yaml
├── dns/
│   ├── validate-zone-separation.yaml
│   └── prevent-split-horizon.yaml
└── management/
    └── deny-overlay-agents-management-vlan.yaml
```

## Enforcement Layers

### Layer 1: Pre-Commit Hooks (Developer Workstation)
- Secret scanning via `gitleaks` or `trufflehog`
- YAML linting with custom rules
- Schema validation via `kubeconform`

**Status:** Not yet implemented (recommend adding `.pre-commit-config.yaml`)

### Layer 2: CI/CD Policy Checks (GitHub Actions)
- Render Flux/Kustomize manifests
- Apply Kyverno policies in CLI mode (test only, no cluster access)
- Fail PR if policy violations detected

**Status:** See [.github/workflows/policy-enforcement.yml](../.github/workflows/policy-enforcement.yml)

### Layer 3: Runtime Admission Control (Kubernetes Cluster)
- Kyverno ClusterPolicies deployed to cluster
- Admission webhooks enforce policies at apply time
- Audit mode logs violations without blocking (for monitoring)

**Status:** Policies defined but not yet deployed to cluster

## Policy Development

### Adding a New Policy

1. **Define the constraint** in `requirements/**/spec.md` or `contracts/*.md`
2. **Create Kyverno policy** in appropriate subdirectory
3. **Add test cases** in `test/policies/<domain>/` with valid/invalid manifests
4. **Update checks** in `requirements/**/checks.md` to reference policy file
5. **Run validation locally**: `task validate:policies`
6. **Deploy to cluster** via Flux when ready

### Testing Policies

```bash
# Test a single policy against a manifest
kyverno apply policies/storage/deny-database-on-longhorn.yaml \
  --resource test/policies/storage/invalid-postgres-longhorn.yaml

# Test all policies
task validate:policies
```

### Policy Naming Convention

- **deny-***: Blocks forbidden patterns (enforcement mode)
- **require-***: Mandates required patterns (enforcement mode)
- **validate-***: Checks complex conditions (enforcement or audit mode)
- **restrict-***: Limits allowed values (enforcement mode)

## Failure Modes Prevented

| Policy | Failure Mode | Rationale |
|--------|--------------|-----------|
| deny-database-on-longhorn | Data loss on node failure | Longhorn not suitable for database workloads ([ADR-0010](../docs/adr/ADR-0010-longhorn-storage.md)) |
| deny-loadbalancer-external-ips | WAN exposure bypass | Violates Cloudflare Tunnel-only ingress ([ADR-0002](../docs/adr/ADR-0002-tunnel-only-ingress.md)) |
| deny-inline-secrets | Secret leakage in git | Violates 1Password/ESO secrets model ([ADR-0004](../docs/adr/ADR-0004-secrets-management.md)) |
| validate-zone-separation | Split-horizon DNS | Bypasses Cloudflare Access ([ADR-0001](../docs/adr/ADR-0001-dns-intent.md)) |
| deny-overlay-agents-management-vlan | Management network compromise | Violates management isolation ([ADR-0003](../docs/adr/ADR-0003-management-network.md)) |

## References

- **Constitution:** [constitution/constitution.md](../constitution/constitution.md)
- **Hard-Stops:** [contracts/hard-stops.md](../contracts/hard-stops.md)
- **Invariants:** [contracts/invariants.md](../contracts/invariants.md)
- **Requirements:** [requirements/](../requirements/)
- **Kyverno Documentation:** https://kyverno.io/docs/
