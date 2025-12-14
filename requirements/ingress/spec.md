# External Ingress Requirements
**Effective:** 2025-12-14

## Ingress policy

- All external ingress MUST be via **Cloudflare Tunnel**
- Direct WAN exposure is forbidden:
  - No port forwards
  - No WAN-exposed listeners
  - No "temporary" openings without an explicit documented exception

## Access control

- Cloudflare Access is the default enforcement point for external human access

## Tunnel scope

| Allowed | Prohibited |
|---------|------------|
| HTTP/HTTPS apps intended for external use | Management infrastructure (BMC/IPMI/KVM/PDUs) |
| Explicitly approved admin UIs | Any management endpoint without explicit approval |

## Rationale

External access is identity-gated via Cloudflare. WAN exposure bypasses this gate and exposes infrastructure directly to the internet.

See: [ADR-0002](../../docs/adr/ADR-0002-tunnel-only-ingress.md)
