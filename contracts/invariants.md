# Invariants
**Effective:** 2025-12-14  
**Authority:** Constitution [AMENDMENT-0003](../constitution/amendments/AMENDMENT-0003-contract-lifecycle.md)

These conditions must **always be true**. Any change that would violate an invariant is invalid.

**Adding/Amending:** See [AMENDMENT-0003](../constitution/amendments/AMENDMENT-0003-contract-lifecycle.md) for procedures.

## Network Identity Invariants

| Resource | Value | Notes |
|----------|-------|-------|
| Management VLAN | 100 | Fixed |
| Management CIDR | `10.0.100.0/24` | Fixed |
| K8s Cluster VLAN | 5 | Fixed |
| K8s Cluster CIDR | `10.0.5.0/24` | Fixed |
| IoT secondary network VLAN | 10 | For Multus workloads |
| LoadBalancer pool VLAN | 48 | For Cilium L2-announced IPs |
| Public zone | `hypyr.space` | Cloudflare-managed |
| Internal zone | `in.hypyr.space` | Local DNS only |

## WAN Constraints

| Resource | Capacity | Stability | Notes |
|----------|----------|-----------|-------|
| Primary WAN (DOCSIS) Upload | 20-30 Mbps | Frequent instability | Residential cable |
| Primary WAN (DOCSIS) Download | 1 Gbps | Frequent instability | Residential cable |
| Secondary WAN (5G) | Variable | Variable | Failover only |

## Storage Configuration Invariants

**Storage System:** Longhorn CSI (see ADR-0010)

All Talos nodes MUST include:
- Kernel modules: `nbd`, `iscsi_tcp`, `dm_multipath`
- System extension: `siderolabs/open-iscsi` (iSCSI initiator)
- Containerd config: `discard_unpacked_layers = false` (for image caching)

Rationale:
- **NBD:** Block device replication (Longhorn volumes)
- **iSCSI:** Data path between replicas in cluster
- **dm_multipath:** Path redundancy for storage reliability
- **open-iscsi:** Daemon for initiating iSCSI connections

These are non-negotiable for Longhorn functionality. Violations break storage.

## Hardware Constraints

| Resource | Quantity | Notes |
|----------|----------|-------|
| Talos k8s nodes | 4 | Commodity/repurposed consumer hardware |
| Total cluster RAM | 352GB | Heterogeneous (32-128GB per node) |
| QuickSync nodes | 2 | Beelink EQ12 units |
| GPU nodes | 1 | Lenovo P520 with NVIDIA P2000 |
| Primary NAS | 1 | 45Drives HL15 (TrueNAS, ~100TB, brownfield) |
| Secondary NAS | 1 | Synology DS918+ (DSM, S3 via Garage, brownfield) |

## Access Invariants

1. **Management network has no Internet egress by default**
   - Egress may be allowed only via explicit allow rules documented in an ADR

2. **Only Mgmt-Consoles may initiate traffic into Management**
   - No other device class may originate connections to Management VLAN

3. **External ingress is Cloudflare Tunnel only**
   - No port forwards
   - No WAN-exposed listeners
   - No "temporary" openings without documented exception

4. **Overlay agents are prohibited on Management VLAN devices**
   - Overlay is transport for trusted humans, not management infrastructure

5. **Secondary networks (IoT, LoadBalancer) must not bypass primary cluster network**
   - VLAN 10 (IoT) provides Multus attachment only; pods remain primarily on K8s network
   - VLAN 48 (LoadBalancer IPs) is L2-announced only; no cluster management traffic
   - No management infrastructure operates on secondary networks

## DNS Invariants

1. **No additional internal suffixes** (`.lan`, `.local`, `.home` are prohibited)

2. **No split-horizon overrides** (public FQDN must not resolve to internal target)

3. **Zone dependency boundaries**:
   - Internal-only services MUST NOT depend on `hypyr.space` resolution
   - Public services MUST NOT depend on `in.hypyr.space` resolution

## Repository Structure Invariants

1. **Root-level files are exhaustively enumerated**
   - Only files explicitly listed in `scripts/enforce-root-structure.sh` may exist in repository root
   - No arbitrary documentation, summaries, or scratch files in root

2. **Markdown files MUST be on allowlist** (see ADR-0025)
   - Only `.md` files explicitly permitted by location/name pattern are allowed
   - Violations blocked by `scripts/enforce-markdown-allowlist.sh` gate
   - Arbitrary summaries, notes, plans (outside `specs/NNN-*/`) prohibited
   - Permitted locations:
     - Root: `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `agents.md`
     - `docs/adr/ADR-NNNN-*.md` (append-only)
     - `docs/`, `docs/governance/`, `docs/operations/`
     - `ops/CHANGELOG.md`, `ops/README.md`, `ops/runbooks/`
     - `requirements/*/spec.md`, `requirements/*/checks.md`
     - `specs/NNN-*/spec.md`, `specs/NNN-*/plan.md`, `specs/NNN-*/research.md`, `specs/NNN-*/data-model.md`, `specs/NNN-*/quickstart.md`, `specs/NNN-*/contracts/`, `specs/NNN-*/checklists/`, `specs/NNN-*/tasks.md`
     - `infra/README.md`, `infra/<domain>/README.md`
   - Domain dirs: `talos/`, `bootstrap/` (README.md and checks.md only; specs relocated to `specs/NNN-*` per ADR-0026)

3. **Specification placement is constrained** (see ADR-0026)
   - Canonical specs **only** under `requirements/<domain>/spec.md`
   - Non-canonical/operational specs **only** under `specs/NNN-<slug>/spec.md`
   - `spec.md` is prohibited in any other path (e.g., `kubernetes/`, `bootstrap/`, `talos/`)
   - Enforced by `scripts/check-spec-placement.sh` and CI gate wiring

4. **Documentation must be properly located**:
   - Architecture decisions → `docs/adr/`
   - General documentation → `docs/`
   - Operational documentation → `ops/runbooks/`
   - Change logs → `ops/CHANGELOG.md` (single file, append-only)
   - Implementation → `infra/<domain>/`

5. **Deployment targets are separated by directory**:
   - Kubernetes workloads → `kubernetes/`
   - NAS/non-K8s workloads → `stacks/` (Docker Compose, systemd units)
   - Infrastructure provisioning → `infra/`

6. **CI enforcement is mandatory**
   - All structural rules MUST be validated in CI (`.github/workflows/guardrails.yml`)
   - PRs violating structure MUST be blocked

7. **NAS stacks are Komodo-managed**
   - NAS/non-Kubernetes stacks are deployed from this repository via TrueNAS Komodo
   - No `stacks/registry.toml` or host-side deploy scripts are required or permitted
   - Each stack directory must be self-contained (compose file + `.env.example`)

## GitOps Invariants

| ID | Description | Risk | Check Script | Remediation |
|----|-------------|------|--------------|-------------|
| `flux-kustomize-builds` | All Flux Kustomization target paths build successfully with kustomize | High | `scripts/check-kustomize-build.sh` | Fix invalid kustomization.yaml, missing resources, or ordering issues |
| `flux-helmrelease-renders` | All HelmReleases can be templated (best-effort) without contacting a cluster | Medium | `scripts/check-helmrelease-template.sh` | Pin chart versions, ensure values refs exist, stub secrets for offline rendering |
| `no-plaintext-secrets` | No Kubernetes Secret manifests stored in plaintext (SOPS-encrypted allowed) | High | `scripts/check-no-plaintext-secrets.sh` | Convert to SOPS, ESO, or sealed secret pattern |
| `deprecated-k8s-apis` | Detect removed/deprecated Kubernetes API versions in manifests | High | `scripts/check-deprecated-apis.sh` | Update manifests to supported apiVersions |
| `talos-ytt-renders` | Talos machine configs render from ytt without missing values | High | `scripts/check-talos-ytt-render.sh` | Fix ytt schema/data-values, eliminate hidden defaults, document required inputs |
| `no-cross-env-leakage` | Flux sources and Kustomizations do not reference paths across clusters/environments | High | `scripts/check-cross-env-refs.sh` | Introduce shared bases or per-cluster overlays; avoid path traversal |
| `crds-before-crs` | CRDs/controllers reconcile before CR instances (ordering validated) | High | `scripts/check-crd-ordering.sh` | Add explicit `dependsOn` and/or split kustomizations into infra/controllers/apps layers |
