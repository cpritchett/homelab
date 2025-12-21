# Storage Classes (Longhorn + NAS + Node-Local)

This runbook defines the Kubernetes storage classes that align with ADR-0010 and the storage requirements.

## Artifacts

### 1) Node-local scratch (`node-local`)
Use local-path-provisioner for cheap, non-replicated scratch on per-node SATA/NVMe.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: node-local
provisioner: rancher.io/local-path
parameters:
  path: /var/lib/local-path            # dedicated mount on each node
  type: DirectoryOrCreate
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
mountOptions:
  - noatime
  - nodiratime
```

### 2) NAS-backed database class (`rwx-db`)
Generic NFS CSI StorageClass for SQL/NoSQL databases requiring RWX and stronger consistency than Longhorn.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rwx-db
provisioner: nfs.csi.k8s.io
parameters:
  server: "${NFS_DB_SERVER}"           # e.g., 192.168.1.50
  share: "${NFS_DB_EXPORT}"            # e.g., /mnt/nas/db
reclaimPolicy: Delete
volumeBindingMode: Immediate           # CSI NFS provisions instantly
allowVolumeExpansion: true
mountOptions:
  - nfsvers=4.1
  - hard
  - noatime
```

### 3) Longhorn replicated default (`longhorn-replicated`)
Keep an explicit class to match ADR-0010 for non-database configs/metadata.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-replicated
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "2"
  dataLocality: best-effort
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

## Procedure
1. Set environment values for the NAS NFS export:
   - `NFS_DB_SERVER`
   - `NFS_DB_EXPORT`
2. Apply the manifests (GitOps preferred; ad-hoc for break-glass):
   ```bash
   kubectl apply -f storage-classes.yaml
   ```
3. Verify:
   ```bash
   kubectl get storageclass
   ```
4. Policy checks (Kyverno):
   - Databases must request `rwx-db`, not `longhorn-replicated` or `node-local`.
   - `node-local` use limited to scratch/temp workloads.
5. Backups:
   - Database backups remain database-native to S3 (Garage); Longhorn snapshots are not used for DBs.

## Notes
- Replace `nfs.csi.k8s.io` with your chosen NAS CSI driver if different.
- If OpenEBS LocalPV is already present, `openebs.io/local` can replace `rancher.io/local-path` with equivalent settings.
- Keep `node-local` path on a dedicated SATA/NVMe mount; do not share with OS or kubelet volumes.
