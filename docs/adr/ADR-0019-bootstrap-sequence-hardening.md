# ADR-0019: Bootstrap Sequence Hardening (CRDs, Secrets, Ordering)

**Status:** Accepted  
**Date:** 2025-12-21  
**Author:** Codex (LLM agent)  
**Supersedes/extends:** [ADR-0017: Talos Bare-Metal Bootstrap Procedure](ADR-0017-talos-baremetal-bootstrap.md)  

## Context

ADR-0017 defines the Talos bootstrap flow but leaves implicit the Kubernetes bootstrap content and ordering needed before Flux reconciliation. The reference flow used in `buroa/k8s-gitops` applies namespaces, a 1Password bootstrap secret, and CRD bundles ahead of app installs. We need an explicit, governance-aligned sequence that:

- Seeds External Secrets and 1Password connectivity without committing secrets
- Pre-installs CRDs for autoscaling/observability stacks
- Excludes envoy-gateway (not used here)
- Keeps kube-vip limited to control-plane VIP per ADR-0016

## Decision

1. **Bootstrap resources (secrets & namespaces) first**
   - Apply `bootstrap/resources.yaml` using `op inject` → `kubectl apply -f -` to create `external-secrets` namespace and the 1Password bootstrap secret. No secret material lands in git.

2. **Seed CRDs (exclude envoy-gateway)**
   - Run Helmfile `bootstrap/helmfile.d/00-crds.yaml` with selector `name!=envoy-gateway` to install required CRDs for KEDA and kube-prometheus-stack only.

3. **Bootstrap app order**
   - Cilium → CoreDNS → Spegel (if available) → cert-manager → External Secrets Operator → 1Password store/ClusterSecretStore → kube-vip apply (control-plane only) → Flux Operator → Flux Instance.
   - Spegel absence must not block later steps; kube-vip remains control-plane-only (ADR-0016).

4. **Flux hand-off**
   - Flux Operator/Instance become the entrypoint after the above prerequisites are applied; subsequent workloads stay under GitOps control.

## Consequences

- Secrets and CRDs required by early workloads are present before Flux reconciliation, reducing failure loops.
- Maintains minimal bootstrap surface by omitting envoy-gateway.
- Aligns operational runbook with governance and invariant expectations (control-plane-only kube-vip, External Secrets model).

## Alternatives Considered

- Keep ADR-0017 sequence implicit and rely on Flux retries — rejected; creates noisy reconciliation and secret bootstrap risk.
- Include envoy-gateway CRDs by default — rejected; not part of this environment and adds unnecessary footprint.

## References

- ADR-0017: Talos Bare-Metal Bootstrap Procedure  
- ADR-0016: Kube-vip Control-Plane Only  
- ADR-0004: Secrets Management  
- `bootstrap/resources.yaml`, `bootstrap/helmfile.d/00-crds.yaml`
