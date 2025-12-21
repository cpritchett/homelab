# ADR-0017: Talos Bare-Metal Bootstrap Procedure

**Status:** Proposed  
**Date:** 2025-12-21  
**Author:** Codex (LLM agent)

## Context

- Cluster runs on bare-metal nodes with Talos Linux; configs rendered via ytt (`talos/templates/`, `values/*`).
- Control-plane VIP (`10.0.48.55`) and LoadBalancer VLAN 48 (`10.0.48.50-200`) are fixed invariants; kube-vip is control-plane-only per ADR-0016.
- Router is prosumer (UniFi Fiber Gateway); avoid excessive BGP chatter.
- Need repeatable, documented bootstrap for new/repaved nodes that fits governance.

## Decision

Define a standardized, repeatable Talos bootstrap for bare-metal nodes:

1) **Render & validate configs** with `./talos/render.sh all` (or per-node) and `./talos/render.sh --validate`. Treat rendered output as ephemeral.
2) **Install Talos OS** on each node using matching factory image; wipe/install with `talosctl install --nodes <ip> --image <factory-img> --wipe --preserve --config rendered/<node>.yaml`.
3) **Bootstrap once**: after all control-plane nodes are installed and reachable on VLAN 5, run `talosctl --nodes <controller> bootstrap` a single time.
4) **Fetch kubeconfig**: `talosctl kubeconfig --nodes <controller> --force kubernetes/kubeconfig`.
5) **Join remaining nodes**: `talosctl apply-config --nodes <node> --file rendered/<node>.yaml` for any non-bootstrapped nodes.
6) **Post-checks**: `talosctl --nodes <all> health`; verify VLAN 48 interfaces, required kernel modules (`nbd`, `iscsi_tcp`, `dm_multipath`), and containerd config per invariants.
7) **App bootstrap trigger**: run `task bootstrap:apps` (helmfile Cilium→CoreDNS→Spegel→kube-vip apply→Flux Operator→Flux Instance) once kubeconfig is in place.

Guardrails:
- Do not enable kube-vip service LB/BGP; it remains control-plane-only (ADR-0016). Cilium owns service IPAM/BGP.
- If ARP fails for kube-vip, BGP fallback uses a distinct ASN and single peer (router) and must be explicitly chosen.
- Secret material is never written to git; use `op inject` for bootstrap secrets.

## Consequences

- Provides one authoritative bootstrap recipe; reduces drift and failed bring-up attempts.
- Ensures control-plane VIP and Cilium LB pools stay aligned with VLAN invariants.
- Minimizes router load by keeping kube-vip off BGP unless explicitly needed.

## Alternatives Considered

- Unstructured, node-by-node manual bootstrap: rejected (error-prone, non-repeatable).
- Using kube-vip for service LoadBalancers: rejected (conflicts with Cilium IPAM/BGP, higher router load).

## References

- ADR-0016: Kube-vip Control-Plane Only
- Talos install docs: https://www.talos.dev/latest/talos-guides/install/bare-metal/
- Talos bootstrap: https://www.talos.dev/latest/talos-guides/bootstrap/
