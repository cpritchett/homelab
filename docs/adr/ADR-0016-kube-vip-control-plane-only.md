# ADR-0016: Kube-vip for Control-Plane VIP only

**Status:** Proposed  
**Date:** 2025-12-21  
**Author:** Codex (LLM agent)

## Context

- The cluster uses Cilium (eBPF) for dataplane, LoadBalancer IPAM, L2 announcements, and BGP control plane.
- LoadBalancer pool lives on VLAN 48 with IPs `10.0.48.50-200`; the control-plane VIP is `10.0.48.55`.
- The home router is a prosumer UniFi Fiber Gateway; BGP sessions should be kept lightweight to avoid undue CPU load (“don’t hammer the peer”).
- Spegel availability at bootstrap may be unknown, so bootstrap must succeed without relying on cached images.
- Hubble is intentionally disabled to conserve resources.

## Decision

1. **Scope of kube-vip**
   - kube-vip is used **only** to provide the control-plane virtual IP on VLAN 48.
   - kube-vip cloud-provider / Service LoadBalancer mode remains **disabled**. Cilium continues to own all service VIPs, LB IPAM, and BGP/L2 advertisements for services.

2. **Operating mode**
   - Primary: ARP/NDP advertisement on interface `bond0.48` (or node-specific equivalent for VLAN 48), leader election enabled.
   - Fallback: If ARP fails in this environment, enable kube-vip **BGP for the single /32 VIP only** using a distinct ASN (recommend `64515`) peering solely with the router; Cilium BGP settings stay unchanged.

3. **BGP behavior (router friendliness)**
   - Do not enable kube-vip BGP unless ARP is proven unreliable.
   - If enabled, use conservative timers (default keepalive/hold), avoid aggressive reconnect loops, and peer only one neighbor (router at `10.0.5.1`).
   - Do not run BFD from kube-vip to the router.

4. **Bootstrap order**
   - Cilium → CoreDNS → Spegel (if available) → **kube-vip apply** → Flux Operator → Flux Instance. kube-vip runs after networking/DNS are up; Spegel absence must not block it.

5. **Observability**
   - Hubble remains **off** by default. Revisit only if an explicit observability gap is documented.

## Consequences

### Positive
- Eliminates overlapping LB controllers (kube-vip vs Cilium) and the risk of conflicting BGP speakers for service VIPs.
- Keeps router load low by avoiding unnecessary BGP sessions/timers for control-plane VIP when ARP suffices.
- Clear fallback path if ARP is unsuitable without disturbing Cilium’s service routing.

### Negative / Trade-offs
- ARP dependence means control-plane reachability relies on correct VLAN tagging and switch behavior; misconfiguration surfaces as VIP flaps.
- If ARP fails and BGP is enabled as fallback, there is operational overhead to manage a second BGP speaker (albeit single prefix).

## Alternatives Considered

1. **Use kube-vip for all Service LoadBalancers**
   - Rejected: conflicts with Cilium IPAM/BGP, duplicates functionality, increases router BGP load.

2. **Enable kube-vip BGP by default**
   - Rejected: unnecessary peer load on prosumer router; ARP works in current topology.

3. **Rely solely on Cilium for control-plane VIP**
   - Rejected: kube-vip provides simpler, well-trodden control-plane HA with minimal coupling to Cilium upgrades.

## References
- Cilium LoadBalancer IPAM and BGP: https://docs.cilium.io/en/stable/network/lb-ipam.html
- kube-vip control-plane usage: https://kube-vip.io/docs/usage/kubernetes/
- LoadBalancer VLAN invariant: `contracts/invariants.md`
- Ingress requirements: `requirements/ingress/spec.md`
