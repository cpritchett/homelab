# Flux EntryPoint Plan (homelab)

## Objectives
- Define Flux sources and Kustomizations that reconcile the homelab cluster GitOps tree per ADR-0018.
- Use GitRepository (or OCI) pointing at `cpritchett/homelab`.
- Reconcile platform before apps; keep bootstrap and runtime separation clear.

## Sources
- `GitRepository` `homelab-root`
  - url: `https://github.com/cpritchett/homelab`
  - ref: `refs/heads/main`
  - interval: 1h (match bootstrap values)
  - path: `./kubernetes` (root for shared components/profiles)
- (Optional later) OCIRepository for charts if adopted; not required for MVP.

## Kustomizations (apply order)
1) `platform`  
   - path: `./kubernetes/clusters/homelab/platform`
   - interval: 10m; prune: true; wait: true
   - dependsOn: []
2) `apps`  
   - path: `./kubernetes/clusters/homelab/apps`
   - interval: 10m; prune: true; wait: true
   - dependsOn: [platform]

## Health checks / options
- serviceAccount: `flux-system` (default)
- retryInterval: 1m; timeout: 5m (adjust as needed)
- drift detection: enable `force: false` initially; revisit after cutover.

## Deliverables
- `gitrepository.yaml` defining homelab-root.
- `kustomization-platform.yaml` pointing to platform path.
- `kustomization-apps.yaml` pointing to apps path with dependsOn platform.

## Migration notes
- Keep bootstrap helmfile stack for initial bring-up; after Flux is stable, platform/app content moves under this tree.
- Align CRD versions in repo with those pre-seeded by bootstrap helmfile to avoid downgrade/upgrade loops.
