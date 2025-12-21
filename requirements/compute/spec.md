# Compute Requirements
**Effective:** 2025-12-21

## Hardware constraints

All compute infrastructure is **commodity/repurposed consumer hardware**.

### Talos k8s nodes (4 nodes)

| Host | RAM | OS Disk | Data Disk | Accelerator | Notes |
|------|-----|---------|-----------|-------------|-------|
| Beelink EQ12 #1 | 32GB | 512GB SSD | 1TB NVMe | QuickSync CPU | Talos node |
| Beelink EQ12 #2 | 32GB | 512GB SSD | 1TB NVMe | QuickSync CPU | Talos node |
| Lenovo P520 | 128GB | 512GB SSD | 1TB NVMe | NVIDIA P2000 | Talos node |
| Custom ITX | 64GB | 512GB SSD | 1TB NVMe | None | Talos node |

**Total cluster capacity:**
- 4 nodes
- 352GB RAM aggregate
- QuickSync: 2 nodes (transcoding)
- NVIDIA: 1 node (GPU workloads)

### NAS infrastructure (brownfield)

| Host | RAM | Storage | Accelerator | Management | Notes |
|------|-----|---------|-------------|------------|-------|
| 45Drives HL15 | 128GB | ~100TB | QuickSync GPU | TrueNAS | Primary storage |
| Synology DS918+ | Variable | Variable | None | Synology DSM | Secondary NAS, volsync target, S3 (Garage) |

**NAS management:**
- Brownfield systems with separate management planes
- Not managed via Talos/k8s
- TrueNAS provides primary storage (NFS/iSCSI/SMB)
- Synology provides backup target + S3-compatible storage via [Garage](https://garagehq.deuxfleurs.fr/)

## Bootstrap requirements

### Talos nodes
- Bootstrap via Talos installer
- Configuration generated via ytt templates (`talos/templates/`)
- Node-specific values in `talos/values/{node}.yaml`
- Secrets via 1Password references (`op://homelab/talos/*`)
- Declarative configuration management via FluxCD GitOps
- Control plane HA considerations with 4-node cluster

**Talos bare-metal bootstrap (canonical):**
- See: [ADR-0017](../../docs/adr/ADR-0017-talos-baremetal-bootstrap.md)
- Render and validate Talos configs via `./talos/render.sh`; install Talos on all control-plane nodes; run single `talosctl bootstrap`; fetch kubeconfig; join remaining nodes; then trigger app bootstrap (`task bootstrap:apps`).

**See:** [ADR-0013](../docs/adr/ADR-0013-ytt-data-values.md), [talos/README.md](../talos/README.md)

### NAS systems
- Pre-existing management (TrueNAS UI, Synology DSM)
- Integration with k8s via CSI drivers (TrueNAS) and S3 API (Garage on Synology)

## Design implications

**Hardware limitations:**
- Consumer-grade reliability (plan for node failures)
- Limited per-node resources (32-128GB RAM, single NVMe per node)
- Heterogeneous cluster (mixed RAM/CPU/GPU)

**Workload placement:**
- QuickSync workloads: affinity to Beelink nodes or HL15
- GPU workloads: affinity to Lenovo P520
- Memory-intensive: affinity to P520 (128GB) or ITX (64GB)

**Storage strategy:**
- Ephemeral: local NVMe per node
- Persistent (non-DB, non-media): Longhorn (in-cluster distributed block storage, 2-3 replicas)
- Persistent (databases, media): TrueNAS CSI (primary) or Synology S3/Garage (backup)
- Backup target: Synology S3/Garage via VolSync + Restic

## Rationale

Commodity hardware keeps costs low but requires architecture that tolerates heterogeneity and consumer-grade failure rates.

See: [ADR-0007: Commodity Hardware Constraints](../../docs/adr/ADR-0007-commodity-hardware-constraints.md)
