# ADR-0018: GitOps Structure Refactor for home-ops

**Status:** Accepted  
**Date:** 2025-12-21  
**Authors:** Codex (proposal for review)  

## Context
- The `home-ops` repository currently mixes cluster-scoped Flux bootstrap, platform components, and application overlays in a shallow `kubernetes/` tree. Historical patterns (e.g., hard-coded StorageClasses like `ceph-block`) do not align with the storage governance in ADR-0010 and updated storage requirements (`longhorn-replicated`, `rwx-db`, `node-local`).
- Introducing a clearer GitOps layout is required before adding new storage classes and database placements. The proposal must remain vendor-neutral and support incremental migration without assuming existing layout is best practice.
- Governance requires ADR approval for canonical process changes; this ADR documents the proposed structure pending approval.

## Decision (proposed)
Adopt a layered GitOps structure for `home-ops` with explicit entrypoints, reusable components, and storage/secret conventions:

### Repository layout
```
kubernetes/
  clusters/
    <cluster>/
      flux/          # Flux system + sources
      platform/      # CNI, CSI, ingress, secrets, monitoring, storage classes
      apps/          # namespace-scoped Flux Kustomizations and app overlays
        <namespace>/
          kustomization.yaml
          <app>/
            base/          # app-agnostic HelmRelease/CRDs/defaults
            overlays/
              default/     # cluster overlay; add others as needed
  components/              # reusable kustomize components (ingress, storage, volsync, psa)
  profiles/                # optional bundles (observability, media)
```

### Storage class selection per app
- `longhorn-replicated` for configs/metadata (RWO, replicas=2, dataLocality=best-effort)
- `rwx-db` generic NAS-backed NFS/iSCSI class for SQL/NoSQL databases
- `node-local` (local-path or OpenEBS LocalPV) for scratch/transcodes; not for databases
- Each app overlay includes a `storageclass-patch.yaml` choosing one of the above.

### Secrets
- Single ClusterSecretStore (1Password Connect) in platform layer.
- All apps consume secrets via ExternalSecret; no inline Secret manifests.

### CI / Policy
- CI runs `kustomize build`/`kubeconform` on `kubernetes/clusters/<cluster>`.
- Kyverno PolicyReports enforce storage rules (deny DB on Longhorn, restrict node-local).
- Renovate limited to overlays (values/versions), not bases.

### Migration approach
- Incremental: introduce `kubernetes/clusters/<cluster>/` alongside existing tree; register new Flux Kustomizations; deprecate old paths after reconciliation succeeds.
- Promote reused bits into `components/` and optional `profiles/` to reduce duplication.
- Replace legacy StorageClass references (`ceph-block`, `openebs-hostpath`) with the standardized classes during overlay migration.

## Consequences
### Positive
- Deterministic reconciliation with clear entrypoints.
- Explicit storage/secret choices aligned with ADR-0010 and storage requirements.
- Reusable components reduce copy/paste and ease policy enforcement.
### Negative / Risks
- Migration effort and temporary dual-path maintenance.
- Potential Flux drift during transition if both trees remain enabled; requires careful cutover plan.
### Mitigations
- Stage-by-stage migration with per-namespace validation.
- Keep Flux Kustomizations mutually exclusive per app during cutover.

## Alternatives considered
1. **Keep current flat layout:** Rejected—difficult to enforce storage/secret policy and reuse.
2. **Big-bang rewrite:** Rejected—higher blast radius; incremental path preferred.
3. **Template-heavy (helmfile/kpt) repo:** Rejected for added tooling overhead in homelab context.

## Status & Next Steps
- Status is **Proposed**; requires approval before implementation in `home-ops`.
- Once approved:
  1. Add `kubernetes/clusters/<cluster>/` skeleton and Flux entrypoint.
  2. Add `components/storage-classes/` with `longhorn-replicated`, `rwx-db`, `node-local`.
  3. Migrate namespaces/apps into overlays with storageclass patches and ExternalSecrets.
  4. Enable CI/policy checks over the new cluster tree; remove legacy paths after stable reconciliation.

## References
- ADR-0010: Longhorn for Non-Database Persistent Storage
- requirements/storage/spec.md
- requirements/storage/checks.md
