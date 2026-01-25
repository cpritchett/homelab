# ADR-0007: Commodity Hardware Constraints

## Status
Accepted

## Context
Homelab infrastructure is built on repurposed and consumer-grade hardware rather than enterprise equipment. This requires architecture that accommodates heterogeneity, limited per-node resources, and consumer-grade reliability.

## Hardware inventory

### Talos Kubernetes cluster (4 nodes)

| Host | RAM | OS Disk | Data Disk | Accelerator | Role |
|------|-----|---------|-----------|-------------|------|
| Beelink EQ12 #1 | 32GB | 512GB SSD | 1TB NVMe | QuickSync CPU | k8s worker |
| Beelink EQ12 #2 | 32GB | 512GB SSD | 1TB NVMe | QuickSync CPU | k8s worker |
| Lenovo P520 | 128GB | 512GB SSD | 1TB NVMe | NVIDIA P2000 | k8s worker |
| Custom ITX | 64GB | 512GB SSD | 1TB NVMe | None | k8s worker |

**Cluster totals:** 352GB RAM, 4TB NVMe ephemeral storage

### NAS infrastructure (brownfield, separate management)

| Host | RAM | Storage | Accelerator | OS | Purpose |
|------|-----|---------|-------------|-----|---------|
| 45Drives HL15 | 128GB | ~100TB | QuickSync GPU | TrueNAS | Primary storage |
| Synology DS918+ | Variable | Variable | None | DSM | Backup target, S3 (Garage) |

## Decision

**Accept hardware heterogeneity and consumer-grade limitations:**
- Mixed node sizes (32-128GB RAM)
- Mixed accelerators (QuickSync, NVIDIA P2000, none)
- No redundant power, no ECC RAM, no enterprise support
- Brownfield NAS systems managed separately from k8s

**Management strategy:**
- Talos nodes: GitOps via FluxCD
- NAS systems: Native management UIs (TrueNAS, Synology DSM)
- Integration via CSI drivers (TrueNAS) and S3 API (Garage on Synology)

**Bootstrap process:**
1. Talos nodes: PXE/ISO boot → declarative config via FluxCD
2. NAS systems: Pre-existing, integrate via network APIs

## Consequences

**Architectural constraints:**
- Plan for node failures (consumer-grade reliability)
- Workload placement awareness (affinity rules for GPU/QuickSync/RAM)
- Limited per-node resources (largest node: 128GB RAM, 1TB NVMe)
- Ephemeral storage per-node; persistent storage via TrueNAS or S3/Garage

**Operational constraints:**
- No enterprise-grade SLAs or support
- Heterogeneous cluster requires documented affinity rules
- Brownfield NAS management outside GitOps scope

**Benefits:**
- Low cost of entry
- Repurposed hardware reduces waste
- Sufficient for homelab workloads

## Links
- [specs/006-talos/spec.md](../../specs/006-talos/spec.md)
- [ADR-0006: WAN Bandwidth Constraints](ADR-0006-wan-bandwidth-constraints.md)
