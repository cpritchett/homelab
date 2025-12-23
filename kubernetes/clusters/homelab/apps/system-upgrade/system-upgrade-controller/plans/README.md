# System Upgrade Plans

Version pins for the System Upgrade Controller plans live in `cluster-versions.yaml`.

- Renovate updates `KUBERNETES_VERSION` and `TALOS_VERSION` in that file.
- Kustomize wires those values into `kubernetes.yaml` and `talos.yaml` via vars.
