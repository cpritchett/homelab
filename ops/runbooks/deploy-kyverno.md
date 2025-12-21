# Kyverno Deployment Checklist

**Purpose:** Deploy Kyverno and policies to Kubernetes cluster for runtime admission control (Layer 3)

**Prerequisites:**
- [ ] Flux deployed and reconciling
- [ ] Cluster has sufficient resources (Kyverno: ~200Mi RAM per replica, 3 replicas recommended)
- [ ] Policies validated in CI (Layer 2) and no issues identified

## Phase 1: Install Kyverno (Audit Mode)

### 1.1 Create Kyverno namespace
```yaml
# infra/kyverno/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kyverno
```

### 1.2 Add Kyverno HelmRepository
```yaml
# infra/kyverno/source.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: kyverno
  namespace: kyverno
spec:
  interval: 1h
  url: https://kyverno.github.io/kyverno/
```

### 1.3 Deploy Kyverno via HelmRelease
```yaml
# infra/kyverno/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: kyverno
  namespace: kyverno
spec:
  interval: 30m
  chart:
    spec:
      chart: kyverno
      version: 3.x.x  # Pin to specific version
      sourceRef:
        kind: HelmRepository
        name: kyverno
  values:
    replicaCount: 3  # HA mode
    resources:
      requests:
        memory: 128Mi
        cpu: 100m
      limits:
        memory: 256Mi
        cpu: 500m
    # Start in audit mode (don't block anything yet)
    config:
      webhooks:
        - failurePolicy: Ignore  # Fail-open during initial deployment
```

### 1.4 Verify Kyverno installation
```bash
kubectl -n kyverno get pods
kubectl -n kyverno logs -l app.kubernetes.io/name=kyverno
```

**Expected:** 3 kyverno pods running, no errors in logs

---

## Phase 2: Deploy Policies (Audit Mode)

### 2.1 Create Kustomization for policies
```yaml
# infra/policies/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../policies/storage/deny-database-on-longhorn.yaml
  - ../../policies/storage/enforce-longhorn-replicas.yaml
  - ../../policies/storage/restrict-rwx-access-mode.yaml
  - ../../policies/storage/limit-volume-size.yaml
  - ../../policies/ingress/deny-loadbalancer-external-ips.yaml
  - ../../policies/ingress/deny-nodeport-services.yaml
  - ../../policies/secrets/deny-inline-secrets.yaml

# Override all policies to Audit mode initially
patchesStrategicMerge:
  - |-
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: not-used
    spec:
      validationFailureAction: Audit
```

### 2.2 Add Flux Kustomization
```yaml
# infra/kyverno/policies-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kyverno-policies
  namespace: flux-system
spec:
  interval: 10m
  path: ./infra/policies
  prune: true
  sourceRef:
    kind: GitRepository
    name: homelab
  dependsOn:
    - name: kyverno
```

### 2.3 Verify policy deployment
```bash
kubectl get clusterpolicies
kubectl get policyreports -A
```

**Expected:** All policies deployed in Audit mode, PolicyReports being generated

---

## Phase 3: Monitor & Validate (7-30 days)

### 3.1 Review PolicyReports
```bash
# List all policy violations
kubectl get policyreports -A -o json | jq '.items[].results[] | select(.result=="fail")'

# Count violations by policy
kubectl get policyreports -A -o json | jq '.items[].results[] | select(.result=="fail") | .policy' | sort | uniq -c

# Violations in specific namespace
kubectl get policyreport -n <namespace> -o yaml
```

### 3.2 Fix violations
For each violation:
- [ ] Determine if violation is legitimate (prohibited pattern) or false positive
- [ ] If legitimate: Modify resource to comply OR add override annotation with ADR
- [ ] If false positive: Refine policy to allow valid pattern
- [ ] Document decision in issue/PR

### 3.3 Validate no unexpected violations
- [ ] No critical workloads blocked
- [ ] No false positives for known-good patterns
- [ ] Override annotations used appropriately with ADRs

---

## Phase 4: Switch to Enforce Mode

### 4.1 Update policies to Enforce (one domain at a time)

**Option A: Update policy files directly**
```yaml
# policies/storage/deny-database-on-longhorn.yaml
spec:
  validationFailureAction: Enforce  # Changed from Audit
```

**Option B: Remove Audit mode patch from Kustomization**
```yaml
# infra/policies/kustomization.yaml
# Remove or comment out the Audit mode patch
```

### 4.2 Rollout order (least to most disruptive)

1. **Secrets domain** (low risk, high value)
   - [ ] `deny-inline-secrets.yaml` → Enforce

2. **Storage domain** (medium risk, high value)
   - [ ] `enforce-longhorn-replicas.yaml` → Enforce
   - [ ] `limit-volume-size.yaml` → Enforce
   - [ ] `restrict-rwx-access-mode.yaml` → Enforce
   - [ ] `deny-database-on-longhorn.yaml` → Enforce

3. **Ingress domain** (high risk, high value)
   - [ ] `deny-nodeport-services.yaml` → Enforce
   - [ ] `deny-loadbalancer-external-ips.yaml` → Enforce

### 4.3 Test enforcement
```bash
# Test policy blocks prohibited pattern
kubectl apply -f test/policies/storage/invalid/invalid-postgres-longhorn.yaml

# Expected: Error from admission webhook
```

### 4.4 Update Kyverno webhook failure policy
```yaml
# infra/kyverno/helmrelease.yaml
spec:
  values:
    config:
      webhooks:
        - failurePolicy: Fail  # Changed from Ignore (fail-closed)
```

**Critical:** Only switch to `Fail` after policies validated in Enforce mode

---

## Phase 5: Observability & Maintenance

### 5.1 Set up PolicyReport monitoring

**Prometheus metrics (if using Kyverno exporter):**
```yaml
# Example PrometheusRule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kyverno-policies
spec:
  groups:
    - name: kyverno
      rules:
        - alert: KyvernoPolicyViolation
          expr: kyverno_policy_results_total{result="fail"} > 0
          labels:
            severity: warning
          annotations:
            summary: "Policy violation detected"
```

**Grafana dashboard:**
- PolicyReport violations by namespace
- Violations by policy
- Trend over time

### 5.2 Quarterly policy review

- [ ] Review all override annotations
- [ ] Expire or renew annotations per ADR expiration dates
- [ ] Review PolicyReports for new patterns
- [ ] Update policies based on lessons learned

### 5.3 Policy update process

When updating policies:
1. [ ] Update policy YAML in `policies/`
2. [ ] Update test cases in `test/policies/`
3. [ ] Run `task test:policies` locally
4. [ ] Open PR (CI validates)
5. [ ] Flux automatically applies to cluster
6. [ ] Monitor PolicyReports for 24-48 hours
7. [ ] Roll back if issues detected

---

## Rollback Plan

### If policies cause issues in production

1. **Immediate (minutes):**
   ```bash
   # Switch policy to Audit mode
   kubectl patch clusterpolicy <policy-name> --type merge -p '{"spec":{"validationFailureAction":"Audit"}}'
   ```

2. **Temporary (hours):**
   ```bash
   # Disable specific policy
   kubectl annotate clusterpolicy <policy-name> policies.kyverno.io/disabled=true
   ```

3. **Emergency (minutes):**
   ```bash
   # Disable all policies (nuclear option)
   kubectl scale deploy kyverno -n kyverno --replicas=0
   ```

4. **Post-incident:**
   - [ ] Document what went wrong
   - [ ] Fix policy or add override annotation
   - [ ] Re-enable policies
   - [ ] Update runbook

---

## Success Criteria

- [ ] Kyverno running in HA mode (3 replicas)
- [ ] All policies deployed and enforcing
- [ ] No false positives blocking legitimate workloads
- [ ] PolicyReports integrated with monitoring
- [ ] Alerts configured for policy violations
- [ ] Rollback procedures tested
- [ ] Documentation updated

---

## References

- **Kyverno Installation:** https://kyverno.io/docs/installation/
- **Policy Architecture:** [docs/policy-enforcement.md](../docs/policy-enforcement.md)
- **Policy Definitions:** [policies/](../policies/)
- **Test Cases:** [test/policies/](../test/policies/)
- **Flux Kustomization:** https://fluxcd.io/flux/components/kustomize/kustomization/
