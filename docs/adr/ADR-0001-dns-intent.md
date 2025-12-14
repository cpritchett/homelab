# ADR-0001: DNS Intent Domains

## Status
Accepted

## Context
Split-horizon DNS with identical FQDNs creates ambiguity and bypass risk when combined with tunnels, overlays, and automation.

## Decision
Define two intent domains:
- `hypyr.space` — public, Cloudflare-managed
- `in.hypyr.space` — internal-only, authoritative on internal DNS

Public and internal services must use distinct hostnames.

## Consequences
- Clear trust boundaries
- Simpler debugging and ops
- Reduced accidental exposure

## Links
- [requirements/dns/spec.md](../../requirements/dns/spec.md)
