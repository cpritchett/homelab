# Storage Requirements
**Effective:** 2025-12-21

## Storage planes

This homelab infrastructure uses **separate storage planes** for different workload classes.

### Required StorageClasses (defined under `kubernetes/components/storage-classes/`)
- `longhorn-replicated` — RWO replicated (default for configs/metadata)
- `node-local` — node-pinned scratch (ephemeral-only, no expansion)
- `nfs-media` — RWX NAS for media/large POSIX data
- `nfs-backup` — RWX NAS for backup staging
- `rwx-db` — RWX NAS for databases requiring shared POSIX
- `s3-snapshot` — VolumeSnapshotClass for Longhorn backups to S3 (VolSync/Restic)

**Value sourcing:**
- NFS classes require env inputs: `NFS_MEDIA_SERVER/PATH`, `NFS_BACKUP_SERVER/PATH`, `NFS_DB_SERVER/PATH`.
- `s3-snapshot` requires `S3_SNAPSHOT_ENDPOINT/REGION/BUCKET/ACCESS_KEY/SECRET_KEY` (supply via ExternalSecret/ksops, not committed).

**Node-local guardrail:** Node-local is for ephemeral/scratch only; Kyverno policy `deny-node-local-for-critical-data` enforces this unless annotated `storage.hypyr.space/ephemeral: "true"`.

### Longhorn (in-cluster distributed block storage)

**Scope:** Non-database, non-media workloads requiring node-failure tolerance

**Allowed use cases:**
- Application configuration volumes (e.g., *arr stack configs)
- Application metadata (e.g., Plex metadata, not media files)
- Ephemeral/cache volumes for stateful apps
- Small persistent volumes (<100GB per volume typical)
- RWO volumes only (RWX NOT supported unless explicitly approved)

**Prohibited use cases:**
- Database workloads (PostgreSQL, MySQL, MongoDB, etc.)
- Media file storage (movies, TV shows, music)
- Large blob storage (backups, archives)
- Latency-sensitive databases requiring strong consistency
- Any workload requiring strict POSIX guarantees

### NAS-backed database storage (NFS/iSCSI)

**Scope:** SQL/NoSQL databases requiring stronger consistency and RWX support

**StorageClass:** `rwx-db` (generic NAS-backed NFS/iSCSI class)

**Use cases:**
- PostgreSQL, MySQL, MongoDB, etc.
- Applications that require RWX access or shared DB mounts

**Constraints:**
- Must not use Longhorn
- Backups via database-native tooling to S3 (Garage)

### TrueNAS (external NFS/iSCSI/SMB)

**Scope:** Large media storage, databases requiring strong consistency

**Use cases:**
- Media libraries (movies, TV, music, photos)
- Database persistent volumes (when CSI driver available)
- Large file storage
- SMB shares for legacy apps

### S3-compatible storage (Garage/Synology or equivalent)

**Scope:** Object storage, backup targets via any S3-compatible endpoint (Garage on Synology is current implementation, but any compatible S3 service is acceptable).

**Use cases:**
- VolSync replication targets
- Restic backup repositories
- Application object storage (where S3 API is native)

### Node-local scratch (consumer SATA/NVMe per node)

**StorageClass:** `node-local`

**Provisioner:** Prefer `rancher.io/local-path`; `openebs.io/local` acceptable if OpenEBS is present.

**Configuration:**
- `path: /var/lib/local-path` (dedicated mount on each node)
- `volumeBindingMode: WaitForFirstConsumer`
- `reclaimPolicy: Delete`
- `allowVolumeExpansion: false`
- `fsType: ext4`
- Mount options: `noatime,nodiratime`

**Use cases:**
- Download caches, transcode scratch, temp working dirs
- Embedded SQLite only when application tolerates node loss

**Prohibited:**
- Stateful databases requiring durability
- Any workload needing failover/replication

## Longhorn design constraints

### Replica configuration
- **Default replicas:** 2
- **Minimum replicas:** 2 (single-node failure tolerance)
- **Maximum replicas:** 3 (limited by node count)
- Replica count MUST be explicit in storage class definitions

### Failure model
**Tolerated:**
- Single node failure (replica-based failover)
- Single disk failure per node
- Transient network partitions

**NOT tolerated:**
- Simultaneous multi-node failure
- Split-brain scenarios (Longhorn eventually-consistent model)
- Data corruption from hardware failures (rely on backups)

### Performance expectations
- Consumer-grade NVMe performance (not enterprise SSD/NVMe)
- Network replication overhead (gigabit LAN typical)
- No guarantees on fsync latency
- NOT suitable for latency-sensitive databases

### Backup model
- **Primary:** VolSync + Restic to S3 (Garage on Synology)
- **Frequency:** Per-application requirements (hourly to daily typical)
- **Restore:** Manual restoration from S3 via Restic
- **RPO:** Based on backup frequency (typically 1-24 hours)
- **RTO:** Manual intervention required (minutes to hours)

## Explicit non-goals

Longhorn in this homelab is NOT:
- A database-grade storage system
- A replacement for external NAS for media
- A solution for RWX workloads (unless explicitly approved)
- A guarantee against data loss (backups are authoritative)
- Optimized for IOPS-heavy workloads
- Suitable for strict POSIX compliance requirements

## Operational constraints

### Commodity hardware limitations
- Consumer-grade disk reliability (no ECC, no redundant power)
- Limited IOPS per node (~10K-50K typical for NVMe)
- Network as bottleneck (gigabit LAN, not 10G)
- Mixed node sizes (32-128GB RAM, different CPU generations)

### Cluster constraints
- 4-node Talos cluster (3 available for Longhorn if 1 control-plane-only)
- Total NVMe capacity: ~4TB across nodes
- Heterogeneous node sizing affects placement decisions

### Maintenance expectations
- Node reboots: Longhorn handles replica migration
- Volume expansion: Supported but may require pod restarts
- Snapshot/backup: Handled by VolSync, not Longhorn snapshots
- Recovery: Restore from S3 via Restic, not in-place Longhorn recovery

## Policy enforcement (Kyverno)

**The following policies are enforced via Kyverno ClusterPolicies:**

### 1. Database workload prohibition
**Policy:** [`policies/storage/deny-database-on-longhorn.yaml`](../../policies/storage/deny-database-on-longhorn.yaml)

- Pods with labels/annotations indicating database workloads (e.g., `app.kubernetes.io/component=database`) MUST NOT bind PVCs using Longhorn storage classes
- Common database StatefulSets (postgres, mysql, mongodb, etc.) are denied if using Longhorn
- Override: `storage.hypyr.space/database-on-longhorn-approved: "true"` with ADR reference

### 2. Replica count enforcement
**Policy:** [`policies/storage/enforce-longhorn-replicas.yaml`](../../policies/storage/enforce-longhorn-replicas.yaml)

- Longhorn StorageClass definitions MUST explicitly declare `numberOfReplicas` parameter
- Default replica count MUST be 2 or higher (single-node failure tolerance)
- Maximum replica count is 3 (constrained by 4-node cluster)
- Override: `storage.hypyr.space/single-replica-approved: "true"` for single-replica volumes

### 3. RWX access mode restriction
**Policy:** [`policies/storage/restrict-rwx-access-mode.yaml`](../../policies/storage/restrict-rwx-access-mode.yaml)

- PVCs requesting `ReadWriteMany` access mode on Longhorn storage classes are denied by default
- Override: `storage.hypyr.space/rwx-approved: "true"` with justification annotation

### 4. Volume size limits
**Policy:** [`policies/storage/limit-volume-size.yaml`](../../policies/storage/limit-volume-size.yaml)

- Longhorn PVCs exceeding 500GB trigger a warning (audit mode)
- Longhorn PVCs exceeding 1TB are denied (use TrueNAS instead)

### 5. Media workload prohibition
**Policy:** [`policies/storage/deny-database-on-longhorn.yaml`](../../policies/storage/deny-database-on-longhorn.yaml) (extends to media workloads)

- Pods with labels indicating media server workloads (e.g., `app=plex`, `app=jellyfin`) binding media library paths MUST use TrueNAS, not Longhorn
- Config/metadata volumes for media apps MAY use Longhorn

## Backup integration

### VolSync + Restic workflow
1. Longhorn PVC created for application
2. VolSync ReplicationSource targets the PVC
3. Restic snapshot created and pushed to S3 (Garage)
4. Retention policy applied (e.g., keep 7 daily, 4 weekly, 12 monthly)
5. Restore: Create ReplicationDestination → restore from S3 → mount to new PVC

### What is backed up
- Application config volumes
- Application metadata volumes
- Small persistent state volumes

### What is NOT backed up via VolSync
- Media files (backed up separately or not backed up)
- Ephemeral/cache volumes (no backup needed)
- Database volumes (use database-native backup tools if on Longhorn)

### Restore expectations
- **Manual process:** Human intervention required
- **Time:** Minutes to hours depending on volume size and S3 bandwidth
- **Testing:** Restore procedures MUST be tested periodically
- **Documentation:** Runbooks required for per-application restore

## Rationale

Longhorn provides node-failure tolerance for non-critical workloads without the operational overhead of Ceph. The explicit scope limitations (no databases, no media) prevent misuse and align with commodity hardware constraints.

See: [ADR-0010: Longhorn for Non-Database Persistent Storage](../../docs/adr/ADR-0010-longhorn-storage.md)
