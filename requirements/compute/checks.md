# Compute Checks

Validation checklist for compute infrastructure compliance.

## Manual / CI Checks

### Talos nodes
- [ ] Node count matches 4-node expectation
- [ ] FluxCD manages Talos configuration declaratively
- [ ] Control plane HA configured appropriately for 4-node cluster
- [ ] Node-specific workload affinities documented where needed (QuickSync, GPU, RAM)

### NAS systems
- [ ] TrueNAS management remains separate from k8s management plane
- [ ] Synology management remains separate from k8s management plane
- [ ] TrueNAS CSI driver configured for primary persistent storage
- [ ] Garage S3 API accessible from k8s for backup storage
- [ ] Volsync replication targets Synology

### Hardware constraints
- [ ] Workload resource requests fit within node capacity
- [ ] GPU workloads pinned to P520 node
- [ ] QuickSync workloads pinned to appropriate nodes
- [ ] No assumptions of enterprise-grade hardware reliability in architecture
