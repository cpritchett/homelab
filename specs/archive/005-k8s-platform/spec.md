# Platform Layer Plan (homelab)
> **Non-canonical:** Relocated from kubernetes/clusters/homelab/platform/spec.md on 2026-01-25 per ADR-0026.

## Scope
Cluster-scoped services required before apps: CNI, DNS, registry mirror, cert management, secrets plumbing, control-plane VIP, observability base.

## Components to include (initial)
- Cilium (values derived from bootstrap/values/cilium.yaml)
- CoreDNS (values from bootstrap/values/coredns.yaml)
- Spegel (optional; enable if mirrors reachable)
- cert-manager (CRDs pre-seeded; chart values from bootstrap/values/cert-manager.yaml)
- External Secrets Operator + ClusterSecretStore onepassword
- 1Password Connect deployment (enable once creds injected)
- kube-vip (control-plane VIP only; service/BGP modes off)
- Base monitoring CRDs (kube-prometheus-stack CRDs pre-seeded) — add Prometheus stack later via profiles/apps

## Structure
- `kubernetes/components/<component>` kustomizations for reuse across clusters.
- `kubernetes/clusters/homelab/platform/kustomization.yaml` references component bases with any homelab overlays.

## Ordering (within platform)
1. Cilium
2. CoreDNS
3. Spegel (optional)
4. cert-manager
5. External Secrets Operator
6. 1Password ClusterSecretStore + Connect deployment
7. kube-vip

## Values source
Use the checked-in bootstrap values as authoritative defaults. If a value must differ post-bootstrap, add an overlay patch under `platform/overlays/` (not yet created).

## Deliverables to add
- Component directories under `kubernetes/components/` (e.g., `components/cilium/kustomization.yaml` + manifests/HelmRelease/values ref).
- Platform kustomization entries pointing to those components.
- ExternalSecret and ClusterSecretStore manifests under platform (reuse from bootstrap/onepassword store).

## Constraints
- kube-vip remains control-plane only (ADR-0016).
- ExternalSecrets must target ClusterSecretStore `onepassword`.
- No envoy-gateway in bootstrap CRDs.
