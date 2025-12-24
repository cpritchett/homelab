# Apps Layer Plan (homelab)

## Scope
Namespace-scoped application overlays reconciled after platform is healthy.

## Structure
- `kubernetes/clusters/homelab/apps/kustomization.yaml` aggregates per-namespace kustomizations.
- Each namespace gets a directory: `apps/<namespace>/kustomization.yaml`.
- Each app within a namespace: `apps/<namespace>/<app>/base` + `apps/<namespace>/<app>/overlays/default`.

## Ordering
- Use Kustomization `dependsOn` to ensure shared namespaces/operators (e.g., ESO) are ready before apps consuming secrets.

## Storage/secret patterns
- StorageClass selection per ADR-0018: `longhorn-replicated`, `rwx-db`, `node-local` via patches in overlays.
- Secrets: ExternalSecret only, hitting ClusterSecretStore `onepassword`.

## Initial namespaces to consider (pull from home-ops when migrating)
- observability (Prometheus/Grafana/Loki/Alertmanager)
- networking (ingress/tunnels if applicable)
- media or homelab-specific workloads
- system add-ons that are namespace-scoped (e.g., metrics adapters)

## Deliverables to add
- Namespace manifests (per namespace).
- ExternalSecret templates per app with correct secret keys.
- HelmRelease/Kustomization/Deployment manifests for each app with storage class patches.

## Constraints
- No inline Secrets.
- Respect ingress and DNS invariants (Cloudflare Tunnel only; ExternalDNS annotations per ADR-0015 for services that need DNS).
