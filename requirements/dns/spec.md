# DNS Intent Requirements
**Effective:** 2025-12-14

## Authoritative zones

| Zone | Type | Authority | ExternalDNS Policy |
|------|------|-----------|-------------------|
| `hypyr.space` | Public | Cloudflare-managed | `external` |
| `in.hypyr.space` | Internal | Unifi Fiber Gateway | `internal` |

## Naming rules

- Public services MUST use: `<service>.hypyr.space`
  - Managed via ExternalDNS `external` policy annotation
  - Exposed via Cloudflare Tunnel egress
- Internal-only services MUST use: `<service>.in.hypyr.space`
  - Managed via ExternalDNS `internal` policy annotation
  - Reachable within home network only

## Prohibitions

1. Agents MUST NOT introduce additional "internal suffixes" (e.g. `.lan`, `.local`, `.home`)

2. Agents MUST NOT implement split-horizon overrides that make a public name resolve to an internal target (no "same FQDN, different answers" to bypass Access)

3. Internal-only services MUST NOT depend on `hypyr.space` resolution

4. Public services MUST NOT depend on `in.hypyr.space` resolution

## Implementation

Kubernetes services declare DNS intent via ExternalDNS annotations:
- `external-dns.alpha.kubernetes.io/hostname` with `internal` policy → Unifi Network API
- `external-dns.alpha.kubernetes.io/hostname` with `external` policy → Cloudflare API

## Rationale

DNS encodes intent and trust boundaries. Mixing zones or adding alternative suffixes creates ambiguity that undermines structural safety.

See: 
- [ADR-0001: DNS Intent Domains](../../docs/adr/ADR-0001-dns-intent.md)
- [ADR-0015: ExternalDNS Kubernetes Annotations](../../docs/adr/ADR-0015-externaldns-k8s-annotations.md)
