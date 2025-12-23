# Bootstrap Requirements
**Effective:** 2025-12-22  
**Scope:** Bare-metal cluster bootstrap through Flux hand-off  
**See:** [ADR-0017](../../docs/adr/ADR-0017-talos-baremetal-bootstrap.md), [ADR-0019](../../docs/adr/ADR-0019-bootstrap-sequence-hardening.md), [ADR-0020](../../docs/adr/ADR-0020-bootstrap-storage-governance-codification.md)

## Purpose
Ensure every new/repaved cluster can reach Flux-managed state deterministically, with secrets and CRDs in place, and without exposing WAN or violating invariants.

## Required order (critical path)
1. Render/validate Talos configs; install Talos; single `talosctl bootstrap`; fetch kubeconfig; join remaining nodes.  
2. Apply bootstrap resources via `op inject -i bootstrap/resources.yaml | kubectl apply -f -` (creates `external-secrets` ns + `onepassword-secret`).  
3. Seed CRDs via `helmfile -f bootstrap/helmfile.d/00-crds.yaml template --selector name!=envoy-gateway | kubectl apply -f -`.  
4. Apply bootstrap apps (Helmfile) in this order: Cilium → CoreDNS → Spegel → cert-manager → External Secrets Operator → 1Password store/ClusterSecretStore → kube-vip (control-plane VIP only) → Flux Operator → Flux Instance.  
5. Create Flux Git source + Kustomization pointing at `home-ops` repo/cluster root; verify reconciliation succeeds.

## Required configurations (placeholders)
- `bootstrap/values/cilium.yaml`: set LoadBalancer pool `10.0.48.50-200`, VLAN `48`, BGP timers (router-friendly), Hubble disabled (per ADR-0016).  
- `bootstrap/values/kube-vip.yaml`: set control-plane VIP `10.0.48.55`, interface `bond0.48`, ARP mode; BGP fallback **disabled** by default.  
- `bootstrap/values/cert-manager.yaml`: issuer/default cluster issuer, namespace creation flag.  
- `bootstrap/values/external-secrets.yaml`: serviceAccount, leaderElection, serviceMonitor (if used).  
- `bootstrap/values/onepassword-store.yaml`: Connect URL, credentials ref to `onepassword-secret`; set `installed: true` when populated.  
- `bootstrap/values/flux-operator.yaml` / `flux-instance.yaml`: instance name, namespace create, Git repo URL/branch/path, deploy key/secret refs.  
- `bootstrap/values/spegel.yaml`: registry mirrors or disable if unavailable.  
- `bootstrap/values/common.yaml`: any shared settings (optional).

## Namespace and store constraints
- `onepassword-secret` MUST exist only in `external-secrets` namespace.
- ExternalSecrets MUST use ClusterSecretStore `onepassword`.
- External Secrets Operator deployment MUST be present before applying ExternalSecrets.

## Handoff to GitOps
- Flux Instance must reconcile a `GitRepository` (or OCI source) and `Kustomization` that points to the cluster’s desired state; mismatch blocks completion.
- CRD versions seeded in step 3 must match chart versions in Flux-managed stacks to avoid drift.

## Prohibitions / guards
- Do not enable kube-vip Service/BGP modes; control-plane VIP only (ADR-0016).
- Do not include envoy-gateway CRDs in bootstrap.
- No inline Secrets; use ExternalSecret + 1Password (ADR-0004).

## Rationale
A deterministic, secrets-safe bootstrap reduces failed bring-ups and prevents drift before Flux takes control. Alignment with ADR-0016/0017/0019 preserves ingress and VIP invariants.
