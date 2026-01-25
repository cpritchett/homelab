# VolSync Auto-Restore Model

- VolSync operator deployed in `volsync-system` via platform layer.
- S3-compatible snapshots via VolumeSnapshotClass `s3-snapshot` (driver: driver.longhorn.io).
- Restic creds pulled from ClusterSecretStore `onepassword` using ExternalSecret `volsync-restic`.
- Per-PVC annotations control enforcement:
  - `backup.hypyr.space/auto-backup=true` → must have ReplicationSource
  - `backup.hypyr.space/auto-restore=true` → must have ReplicationDestination
- Kyverno policy `require-volsync-for-annotated-pvc` enforces presence of VolSync CRs.
- Storage classes used by defaults:
  - snapshot/restore: `longhorn-replicated` (RWO) + cache on `node-local`
  - snapshot class: `s3-snapshot`
- Inputs (must be supplied via secrets/vars): S3 endpoint/region/bucket/access/secret.

To onboard an app PVC:
1. Add ExternalSecret (or reuse template) for Restic repo per app if segregated repos are desired.
2. Instantiate ReplicationSource/ReplicationDestination from templates with APP/PVC/NAMESPACE set.
3. Annotate the PVC with `backup.hypyr.space/auto-backup=true` (and auto-restore if desired).
4. Apply; policy will block if CRs are missing.
