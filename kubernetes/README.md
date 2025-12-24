# Kubernetes GitOps Tree (ADR-0018)

This tree follows the layered structure approved in ADR-0018:
- `clusters/<cluster>/flux` — Flux system entrypoint (sources, Kustomizations)
- `clusters/<cluster>/platform` — cluster-scoped platform components (CNI, CSI, ingress, secrets, monitoring, storage classes)
- `clusters/<cluster>/apps` — namespace-scoped application overlays
- `components/` — reusable kustomize components
- `profiles/` — optional bundles (e.g., observability, media)

Cluster-specific trees should be reconciled by the Flux Instance defined in `bootstrap/values/flux-instance.yaml`.
