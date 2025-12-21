# ADRs
Architectural Decision Records explain *why* decisions were made.

## Index
- [ADR-0001](ADR-0001-dns-intent.md): DNS encodes intent boundaries
- [ADR-0002](ADR-0002-tunnel-only-ingress.md): Cloudflare Tunnel for external ingress
- [ADR-0003](ADR-0003-management-network.md): Management network isolation
- [ADR-0004](ADR-0004-secrets-management.md): 1Password for secrets
- [ADR-0005](ADR-0005-externaldns-k8s-annotations.md): ExternalDNS K8s annotations
- [ADR-0006](ADR-0006-wan-bandwidth-constraints.md): WAN bandwidth constraints
- [ADR-0007](ADR-0007-commodity-hardware-constraints.md): Commodity hardware constraints
- [ADR-0008](ADR-0008-developer-tooling-stack.md): Developer tooling stack
- [ADR-0009](ADR-0009-git-workflow-conventions.md): Git workflow conventions
- [ADR-0010](ADR-0010-longhorn-storage.md): Longhorn for non-database storage
- [ADR-0011](ADR-0011-talos-ytt-templating.md): ytt overlays for Talos *(superseded)*
- [ADR-0012](ADR-0012-talos-native-patching.md): talosctl patch *(superseded)*
- [ADR-0013](ADR-0013-ytt-data-values.md): ytt data values for Talos templating ✓

## Status values
- Proposed
- Accepted
- Superseded
- Deprecated

## Rules
- ADRs are append-only history.
- If reversing a decision, add a new ADR that supersedes the old one.
- ADRs should link to relevant specs in `requirements/` where appropriate.
