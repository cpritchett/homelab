# External Ingress Requirements
**Effective:** 2025-12-14

## Ingress policy

- All external ingress MUST be via **Cloudflare Tunnel**
- Direct WAN exposure is forbidden:
  - No port forwards
  - No WAN-exposed listeners
  - No "temporary" openings without an explicit documented exception

## WAN constraints

- **Upload bandwidth:** 20-30 Mbps (DOCSIS residential)
- **Download bandwidth:** 1 Gbps (DOCSIS residential)
- **Stability:** Frequent instability on primary WAN
- **Failover:** 5G secondary WAN available

**Design implications:**
- Avoid upload-heavy external services
- Cache/CDN strategies preferred for content delivery
- Cloudflare Tunnel mitigates instability via persistent connection
- Consider bandwidth budgets when exposing services externally

## Access control

- Cloudflare Access is the default enforcement point for external human access
- NAS services use Authentik for centralized authentication via forward auth pattern

## Authentication architecture

**NAS Services:** Authentik provides SSO authentication for Docker Compose services running on TrueNAS
**Kubernetes Services:** Cloudflare Access provides identity gating for external access

See: [ADR-0024: Authentik Authentication Stack](../../docs/adr/ADR-0024-authentik-authentication-stack.md)

## Tunnel scope

| Allowed | Prohibited |
|---------|------------|
| HTTP/HTTPS apps intended for external use | Management infrastructure (BMC/IPMI/KVM/PDUs) |
| Explicitly approved admin UIs | Any management endpoint without explicit approval |

## Policy enforcement (Kyverno)

**The following policies prevent WAN exposure:**

### 1. LoadBalancer / externalIPs prohibition
**Policy:** [`policies/ingress/deny-loadbalancer-external-ips.yaml`](../../policies/ingress/deny-loadbalancer-external-ips.yaml)

- Services of type `LoadBalancer` are denied by default
- Services with `externalIPs` are always denied (no exceptions)
- Override for internal LoadBalancers: `ingress.hypyr.space/internal-loadbalancer: "true"` with network + justification annotations

### 2. NodePort restriction
**Policy:** [`policies/ingress/deny-nodeport-services.yaml`](../../policies/ingress/deny-nodeport-services.yaml)

- Services of type `NodePort` are denied by default
- Override: `ingress.hypyr.space/nodeport-approved: "true"` with network + justification annotations

## Rationale

External access is identity-gated via Cloudflare. WAN exposure bypasses this gate and exposes infrastructure directly to the internet.

See: 
- [ADR-0002: Tunnel-Only Ingress](../../docs/adr/ADR-0002-tunnel-only-ingress.md)
- [ADR-0006: WAN Bandwidth Constraints](../../docs/adr/ADR-0006-wan-bandwidth-constraints.md)
- [ADR-0016: Kube-vip Control-Plane Only](../../docs/adr/ADR-0016-kube-vip-control-plane-only.md)
