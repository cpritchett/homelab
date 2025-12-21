# ADR-0006: WAN Bandwidth Constraints

## Status
Accepted

## Context
Home network operates on residential DOCSIS with asymmetric bandwidth and frequent instability. External services must account for limited upload capacity and connection reliability.

## Constraints

| Resource | Capacity | Stability |
|----------|----------|-----------|
| Primary WAN Upload | 20-30 Mbps | Frequent instability |
| Primary WAN Download | 1 Gbps | Frequent instability |
| Secondary WAN (5G) | Variable | Variable (failover only) |

## Decision
Document WAN constraints as invariants to inform architecture decisions. Services exposed externally must:
- Minimize upload bandwidth requirements
- Use CDN/caching strategies for content delivery
- Tolerate connection instability
- Leverage Cloudflare Tunnel's persistent connection to mitigate instability

## Consequences
- Upload-heavy services (media streaming out, large file hosting) are impractical for external exposure
- Cloudflare's edge caching becomes critical for external-facing content
- Services should be designed for pull-based patterns rather than push
- Internal services on `in.hypyr.space` unaffected by WAN constraints
- Tunnel reconnection logic handles primary WAN instability

## Links
- [contracts/invariants.md](../../contracts/invariants.md)
- [requirements/ingress/spec.md](../../requirements/ingress/spec.md)
- [ADR-0002: Tunnel-Only Ingress](ADR-0002-tunnel-only-ingress.md)
