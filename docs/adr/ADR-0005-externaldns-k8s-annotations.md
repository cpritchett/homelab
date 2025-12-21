# ADR-0005: ExternalDNS Kubernetes Annotations

## Status
Accepted

## Context
Kubernetes services need automated DNS management for both internal (home network) and external (internet-facing) endpoints. ExternalDNS with annotation-based policies provides declarative DNS lifecycle management.

## Decision
Use ExternalDNS with dual instances:

### ExternalDNS "internal" instance
- **Annotation:** `external-dns.alpha.kubernetes.io/hostname` with `internal` policy
- **Target zone:** `in.hypyr.space` 
- **DNS provider:** Unifi Network API (Unifi Fiber Gateway)
- **Scope:** Services reachable within home network but external to k8s cluster

### ExternalDNS "external" instance
- **Annotation:** `external-dns.alpha.kubernetes.io/hostname` with `external` policy  
- **Target zone:** `hypyr.space` (Cloudflare-managed)
- **Ingress:** Cloudflare Tunnel egress
- **Scope:** Internet-facing services
- **Auth/authz:** To be determined (future ADR)

## Consequences
- Declarative DNS lifecycle coupled to k8s service lifecycle
- Clear annotation-based intent for internal vs external exposure
- Automated DNS record creation/deletion on service deployment/removal
- Maintains constitutional DNS intent boundaries (`hypyr.space` vs `in.hypyr.space`)
- Unifi gateway becomes authoritative for internal zone
- Cloudflare remains authoritative for public zone

## Links
- [requirements/dns/spec.md](../../requirements/dns/spec.md)
- [ADR-0001: DNS Intent Domains](ADR-0001-dns-intent.md)
- [ADR-0002: Tunnel-Only Ingress](ADR-0002-tunnel-only-ingress.md)
