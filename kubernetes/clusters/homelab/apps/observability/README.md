# Observability Apps (homelab)
- Namespace: `observability` (defined once at this level)
- Included stacks:
  - Keda
  - Kube Prometheus Stack (storageClass: longhorn-replicated)
  - Loki (single binary, storageClass: longhorn-replicated)
  - Grafana (persistence disabled)
  - Blackbox Exporter
