# Storage Checks

Validation checklist for storage compliance.

## Manual / CI Checks

### Longhorn scope compliance
- [ ] No database workloads (PostgreSQL, MySQL, MongoDB) binding Longhorn PVCs
- [ ] No media library paths mounted on Longhorn volumes
- [ ] Media app config/metadata volumes MAY use Longhorn
- [ ] Large blobs (>1TB) rejected for Longhorn, directed to TrueNAS

### Replica configuration
- [ ] All Longhorn StorageClasses explicitly declare `numberOfReplicas`
- [ ] Default replica count is 2 or 3
- [ ] Single-replica volumes have explicit approval annotation
- [ ] Replica count matches node availability (max 3 for 3-node cluster)

### Access mode restrictions
- [ ] RWX (ReadWriteMany) PVCs on Longhorn denied by default
- [ ] RWX exceptions have explicit approval annotation
- [ ] RWO (ReadWriteOnce) is default access mode

### Volume size limits
- [ ] Longhorn PVCs >500GB flagged for review
- [ ] Longhorn PVCs >1TB rejected (redirect to TrueNAS)
- [ ] Volume size expectations documented per application

### Storage class selection
- [ ] Databases (SQL/NoSQL) use NAS-backed StorageClass (e.g., `rwx-db`), not Longhorn
- [ ] Node-local StorageClass (`node-local`) exists and is scoped to scratch/temp only
- [ ] Node-local class uses `WaitForFirstConsumer`, `Delete` reclaim policy, and ext4
- [ ] Application manifests avoid databases on node-local/Longhorn classes
- [ ] NFS classes configured with servers/paths (`nfs-media`, `nfs-backup`, `rwx-db`)
- [ ] `s3-snapshot` VolumeSnapshotClass configured for VolSync/Restic (no credentials committed)

### Backup compliance
- [ ] VolSync ReplicationSource configured for persistent Longhorn volumes
- [ ] Restic repository configured (S3 via Garage on Synology)
- [ ] Backup retention policies defined and enforced
- [ ] Restore procedures documented and tested

### Policy enforcement (Kyverno)
- [ ] `policies/storage/deny-database-on-longhorn.yaml` deployed to cluster
- [ ] `policies/storage/enforce-longhorn-replicas.yaml` deployed to cluster
- [ ] `policies/storage/restrict-rwx-access-mode.yaml` deployed to cluster
- [ ] `policies/storage/limit-volume-size.yaml` deployed to cluster
- [ ] CI policy validation job passes on all PRs (`.github/workflows/policy-enforcement.yml`)
- [ ] Policy violations logged and alerted (Kyverno PolicyReports monitored)

### Operational readiness
- [ ] Node failure scenarios tested (1 node down, replica migration)
- [ ] Volume expansion tested for selected workloads
- [ ] Restore from S3 tested for critical volumes
- [ ] Longhorn monitoring integrated (disk usage, replica health)

### Documentation
- [ ] Per-application storage requirements documented
- [ ] Backup/restore runbooks present in ops/runbooks/
- [ ] Storage class selection guide available
- [ ] Known limitations documented (no databases, no media blobs)
