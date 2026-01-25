# Bootstrap Checks
**Purpose:** Validate bootstrap prerequisites and ordering align with ADR-0017/ADR-0019.

- [ ] `bootstrap/resources.yaml` applied with `op inject` (onepassword-secret present in `external-secrets`).
- [ ] CRDs applied from `bootstrap/helmfile.d/00-crds.yaml` with selector `name!=envoy-gateway`.
- [ ] `task bootstrap:apps` (or helmfile) runs ordered sequence: Cilium → CoreDNS → Spegel → cert-manager → External Secrets → 1Password store → kube-vip (CP only) → Flux Operator → Flux Instance.
- [ ] Flux Git source + Kustomization point to `home-ops` repo/cluster root and reconcile successfully.
- [ ] Kube-vip config confirms service/BGP modes disabled (CP VIP only).
