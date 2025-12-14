# ADR-0003: Management Network Isolation

## Status
Accepted

## Context
Management endpoints (BMC, IPMI, KVM, PDUs, network gear) require stronger isolation than general services.

## Decision
- Management VLAN: 100
- Management CIDR: `10.0.100.0/24`
- Only `Mgmt-Consoles` may access management
- No default Internet egress from management

## Consequences
- Reduced blast radius
- Predictable operational boundary

## Links
- [requirements/management/spec.md](../../requirements/management/spec.md)
