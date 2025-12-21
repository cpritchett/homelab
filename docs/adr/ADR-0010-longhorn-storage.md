# ADR-0010: Longhorn for Non-Database Persistent Storage

## Status
Accepted

## Context
Talos Kubernetes cluster on commodity hardware requires persistent storage that can survive single-node failures for non-critical workloads (e.g., application configs, metadata). Media data lives on external NAS (TrueNAS). Databases require strong consistency and are out of scope for this decision.

### Prior experience
- **Ceph rejected:** Operational complexity, resource overhead, and hardware requirements exceed homelab tolerances. Prior experience showed Ceph consuming significant operator time for minimal benefit on 3-4 node commodity clusters.
- **Local PV rejected:** No node-failure tolerance, manual recovery burden.
- **NFS for everything rejected:** Single point of failure for application configs, increased latency for small volumes.

### Hardware constraints (from ADR-0007)
- 4 Talos nodes: 2x Beelink EQ12 (32GB), 1x Lenovo P520 (128GB), 1x Custom ITX (64GB)
- Total cluster RAM: 352GB
- Per-node NVMe: 1TB (consumer-grade, not enterprise SSD)
- Network: Gigabit LAN (not 10G)
- No redundant power, no ECC RAM, no enterprise support

### Storage workload classes
1. **Media files:** External NAS (TrueNAS HL15, ~100TB)
2. **Application configs/metadata:** Need node-failure tolerance, small volumes (<100GB typical)
3. **Databases:** Strong consistency required, latency-sensitive
4. **Backups:** S3-compatible object storage (Garage on Synology)

## Decision

**Adopt Longhorn for non-database, non-media persistent storage** with the following explicit scope:

### Allowed use cases
- Application configuration volumes (e.g., Sonarr, Radarr, Prowlarr configs)
- Application metadata (e.g., Plex metadata database, NOT media files)
- Ephemeral/cache volumes for stateful apps
- Small persistent volumes (<100GB per volume typical)
- RWO (ReadWriteOnce) volumes only

### Prohibited use cases
- Database workloads (PostgreSQL, MySQL, MongoDB, Redis, etc.)
- Media file storage (movies, TV shows, music, photos)
- Large blob storage (>1TB volumes)
- RWX (ReadWriteMany) workloads (unless explicitly approved)
- Any workload requiring strict POSIX guarantees or sub-millisecond fsync latency

### Configuration
- **Default replicas:** 2 (tolerate 1 node failure)
- **Maximum replicas:** 3 (limited by node count)
- **Storage backend:** NVMe local disks per node
- **Network:** Gigabit LAN for replica traffic

### Backup strategy
- **Primary:** VolSync + Restic to S3 (Garage on Synology)
- **Frequency:** Per-application (hourly to daily typical)
- **RPO:** 1-24 hours (based on backup schedule)
- **RTO:** Manual restore, minutes to hours

## Alternatives considered

### Ceph/Rook
**Rejected:** Operational overhead, resource consumption, and complexity outweigh benefits for homelab scale.

**Why Ceph was considered:**
- Industry-standard distributed storage
- Strong consistency, RWX support
- Mature Rook operator

**Why Ceph was rejected:**
- Minimum 3+ dedicated OSD nodes recommended (conflicts with mixed-workload nodes)
- RAM overhead: 2-4GB per OSD, 16GB+ per MON/MGR
- CPU overhead: Background scrubbing, rebalancing
- Operational complexity: Cluster health monitoring, OSD replacement, PG management
- Prior homelab experience: Spent more time debugging Ceph than using it
- Overkill for "survive node failure" goal (not "run a bank")

### OpenEBS (Mayastor, cStor)
**Rejected:** Similar complexity to Ceph, less mature, higher resource requirements.

### Rook + NFS
**Rejected:** Single NFS server is SPOF; distributed NFS adds Ceph-like complexity.

### Portworx
**Rejected:** Licensing costs, not suitable for homelab.

### Local PV + manual replica management
**Rejected:** No automatic failover, high operational burden.

## Consequences

### Benefits
- **Operationally simple:** Web UI, straightforward setup, minimal tuning
- **Node-failure tolerance:** 2-3 replicas survive single-node loss
- **Resource-efficient:** Lower overhead than Ceph on commodity hardware
- **Backup integration:** Works with VolSync + Restic for off-cluster snapshots
- **Talos-compatible:** Runs on Talos without special kernel modules

### Limitations (acknowledged and accepted)
- **Eventual consistency:** Not suitable for databases requiring strong consistency
- **Network bottleneck:** Replica traffic limited by gigabit LAN
- **No RWX by default:** StatefulSets only, no shared filesystems
- **Consumer hardware risks:** Node failures, disk failures, bit rot (mitigated by backups)
- **Not database-grade:** Fsync latency, consistency model not suitable for PostgreSQL/MySQL

### Operational expectations
- **Node reboots:** Longhorn handles replica migration (minutes of disruption)
- **Node failure:** Pods reschedule, volumes reattach on surviving nodes
- **Volume expansion:** Supported but may require pod restarts
- **Backups:** Rely on VolSync + Restic, NOT Longhorn snapshots
- **Restore:** Manual process, human-in-the-loop

### Risk mitigations
- **Data loss:** Backups to S3 (Garage) are authoritative, test restores periodically
- **Split-brain:** Longhorn eventually-consistent model prevents true split-brain, but may cause stale reads during partitions
- **Performance degradation:** Accept as homelab tradeoff, monitor and adjust replica count if needed
- **Scope creep:** Policy enforcement (Kyverno/OPA) prevents databases/media on Longhorn

## Policy enforcement

The following policies MUST be enforced (via Kyverno or OPA):

1. **Database prohibition:** Deny PVCs with Longhorn storage class for database workloads
2. **Replica count:** Require explicit `numberOfReplicas` in StorageClass, minimum 2
3. **RWX restriction:** Deny `ReadWriteMany` access mode by default
4. **Volume size limits:** Warn >500GB, deny >1TB

See: [requirements/storage/spec.md](../../requirements/storage/spec.md)

## Links
- [Longhorn documentation](https://longhorn.io/docs/)
- [ADR-0007: Commodity Hardware Constraints](ADR-0007-commodity-hardware-constraints.md)
- [requirements/compute/spec.md](../../requirements/compute/spec.md)
- [requirements/storage/spec.md](../../requirements/storage/spec.md)
