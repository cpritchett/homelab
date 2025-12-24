# VolSync Templates (S3-compatible)

Usage pattern (per app/PVC)
1) Set env/vars when rendering:
   - APP: app id (used in VolSync CR names/secret names)
   - PVC: target PVC name
   - NAMESPACE: namespace of the PVC
   - Optional overrides: VOLSYNC_SCHEDULE, VOLSYNC_SNAPSHOTCLASS (default s3-snapshot), VOLSYNC_STORAGECLASS (default longhorn-replicated), VOLSYNC_CACHE_STORAGECLASS (default node-local)
2) Instantiate the component in your app kustomization:
```yaml
components:
  - ../../../../components/volsync/templates
```
3) Provide Restic/S3 creds in 1Password item (default key `volsync-restic`) with:
   - RESTIC_REPOSITORY (full s3:... path)
   - RESTIC_PASSWORD
   - S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY
   - S3_REGION
   - S3_ENDPOINT
4) Annotate the PVC:
   - `backup.hypyr.space/auto-backup: "true"`
   - `backup.hypyr.space/auto-restore: "true"` (if you want restore-on-bootstrap)

What this component generates
- ExternalSecret `${APP}-restic` in `${NAMESPACE}` -> Secret `${APP}-restic-secret`
- ReplicationSource for `${PVC}` (schedule defaults to `15 */8 * * *`)
- ReplicationDestination (manual trigger `restore-once`) using `s3-snapshot`, data on `longhorn-replicated`, cache on `node-local`

Governance
- Kyverno policy `require-volsync-for-annotated-pvc` enforces that annotated PVCs have matching VolSync CRs.
- Storage classes used are approved: `longhorn-replicated`, `node-local`, `s3-snapshot`.
