# Storage Classes (ADR-0010)

Classes defined:
- `longhorn-replicated` — RWO, replicas=2, best-effort locality
- `node-local` — local-path, node-pinned scratch (ephemeral only)
- `nfs-media` — RWX NFS (TrueNAS) for media/large POSIX data
- `nfs-backup` — RWX NFS for backup staging
- `rwx-db` — RWX NFS for NAS-backed databases (use only when NAS latency acceptable)
- `s3-snapshot` — VolumeSnapshotClass for Longhorn S3 backups (VolSync/Restic)

Parameters
- NFS classes require `NFS_MEDIA_SERVER/PATH`, `NFS_BACKUP_SERVER/PATH`, `NFS_DB_SERVER/PATH`.
- s3-snapshot requires `S3_SNAPSHOT_ENDPOINT/REGION/BUCKET/ACCESS_KEY/SECRET_KEY`.

Supply values
- Provide these via your kustomize/Flux variable substitution or envsubst before apply.
- Do NOT commit real credentials; use ExternalSecret/ksops for S3 keys if possible.
