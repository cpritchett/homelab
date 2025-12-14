# ADR-0002: Cloudflare Tunnel–Only Ingress

## Status
Accepted

## Context
Port forwarding and WAN-exposed services expand attack surface and increase operational fragility.

## Decision
All external ingress is via Cloudflare Tunnel with Cloudflare Access as the default enforcement point.

## Consequences
- Zero WAN-exposed services by default
- Identity-based access control
- Cleaner audit trail (Cloudflare-side)

## Links
- [requirements/ingress/spec.md](../../requirements/ingress/spec.md)
