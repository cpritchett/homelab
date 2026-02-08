# ADRs
Architectural Decision Records explain *why* decisions were made.

## Index
- [ADR-0001](ADR-0001-dns-intent.md): DNS encodes intent boundaries
- [ADR-0002](ADR-0002-tunnel-only-ingress.md): Cloudflare Tunnel for external ingress
- [ADR-0003](ADR-0003-management-network.md): Management network isolation
- [ADR-0004](ADR-0004-secrets-management.md): 1Password for secrets
- [ADR-0005](ADR-0005-agent-governance-procedures.md): Agent governance procedures
- [ADR-0015](ADR-0015-externaldns-k8s-annotations.md): ExternalDNS K8s annotations
- [ADR-0006](ADR-0006-wan-bandwidth-constraints.md): WAN bandwidth constraints
- [ADR-0007](ADR-0007-commodity-hardware-constraints.md): Commodity hardware constraints
- [ADR-0008](ADR-0008-developer-tooling-stack.md): Developer tooling stack
- [ADR-0009](ADR-0009-git-workflow-conventions.md): Git workflow conventions
- [ADR-0010](ADR-0010-longhorn-storage.md): Longhorn for non-database storage
- [ADR-0011](ADR-0011-talos-ytt-templating.md): ytt overlays for Talos *(superseded)*
- [ADR-0012](ADR-0012-talos-native-patching.md): talosctl patch *(superseded)*
- [ADR-0013](ADR-0013-ytt-data-values.md): ytt data values for Talos templating ✓
- [ADR-0014](ADR-0014-governance-framework.md): Governance framework and policy enforcement ✓
- [ADR-0020](ADR-0020-bootstrap-storage-governance-codification.md): Bootstrap, storage, and repository governance codification
- [ADR-0021](ADR-0021-truenas-scale-apps.md): TrueNAS SCALE apps for NAS stacks *(superseded by ADR-0022)*
- [ADR-0022](ADR-0022-truenas-komodo-stacks.md): Komodo-managed NAS stacks (supersedes ADR-0021)
- [ADR-0023](ADR-0023-scripts-stacks-classification.md): Scripts vs stacks classification
- [ADR-0024](ADR-0024-speckit-workflow-non-canonical.md): Speckit workflow non-canonical
- [ADR-0025](ADR-0025-strict-markdown-governance.md): Strict markdown governance
- [ADR-0026](ADR-0026-spec-placement-governance.md): Spec placement governance
- [ADR-0027](ADR-0027-agent-template-enforcement.md): Agent template enforcement
- [ADR-0028](ADR-0028-constitutional-governance-authority.md): Constitutional governance authority
- [ADR-0029](ADR-0029-contract-lifecycle-procedures.md): Contract lifecycle procedures
- [ADR-0030](ADR-0030-agent-governance-steering.md): Agent governance steering
- [ADR-0031](ADR-0031-automated-release-process.md): Automated release process
- [ADR-0032](ADR-0032-onepassword-connect-swarm.md): 1Password Connect for Docker Swarm secrets ✓
- [ADR-0033](ADR-0033-truenas-swarm-migration.md): TrueNAS Scale migration with hybrid Kubernetes/Swarm architecture ✓
- [ADR-0034](ADR-0034-label-driven-infrastructure.md): **Label-Driven Infrastructure Pattern (Caddy + AutoKuma)** ✓

## Status values
- Proposed
- Accepted
- Superseded
- Deprecated

## Rules
- ADRs are append-only history.
- If reversing a decision, add a new ADR that supersedes the old one.
- For minor clarifications, create an amendment: `ADR-NNNN-amendment-A.md`
- ADRs should link to relevant specs in `requirements/` where appropriate.

**Authority:** ADR lifecycle is defined in the constitution. See [AMENDMENT-0002](../../constitution/amendments/AMENDMENT-0002-adr-lifecycle.md) for supersede vs amend guidance.
