# Talos Bare-Metal Bootstrap Runbook

**Status:** Draft (follows ADR-0017)

## Pre-reqs
- `talosctl`, `ytt`, `jq`, `kubectl`, `helmfile`, `op` installed (via mise/task stack)
- Access to 1Password vault entries for Talos secrets (op CLI logged in)
- Network: nodes reachable on K8s VLAN (5); VLAN 48 available for LB

## Steps
1) Render configs
```bash
./talos/render.sh all
./talos/render.sh --validate
```

2) Install Talos OS (per node)
```bash
IMAGE="factory.talos.dev/..."
nodes=(10.0.5.215 10.0.5.220 10.0.5.100)
for n in "${nodes[@]}"; do
  talosctl install --nodes "$n" --image "$IMAGE" \
    --wipe --preserve --config rendered/$(talosctl config info --output json | jq -r '.endpoints[0]')
done
```
*(adjust rendered/<node>.yaml per host)*

3) Bootstrap control plane (once)
```bash
talosctl --nodes <controller-ip> bootstrap
```

4) Fetch kubeconfig
```bash
talosctl kubeconfig --nodes <controller-ip> --force kubernetes/kubeconfig
```

5) Join remaining nodes
```bash
talosctl apply-config --nodes <node-ip> --file rendered/<node>.yaml
```

6) Post-checks
```bash
talosctl --nodes <all-ips> health
kubectl get nodes
# verify modules
for n in <all-ips>; do talosctl -n $n read /proc/modules | grep -E 'nbd|iscsi_tcp|dm_multipath'; done
```

7) App bootstrap
```bash
task bootstrap:apps
```
(Helmfile applies Cilium → CoreDNS → Spegel → kube-vip apply → Flux Operator → Flux Instance.)

## Notes
- kube-vip is control-plane VIP only; service LB stays with Cilium (ADR-0016).
- If ARP fails for kube-vip, BGP fallback requires explicit enablement and distinct ASN to avoid router load.
- Secrets are injected at apply time (`op inject` in Task/Helmfile), never committed.

## Rollback/Recovery
- Reinstall node: rerun install with the same rendered config.
- Control-plane recovery: re-bootstrap only if etcd quorum lost; otherwise apply-config and let Cilium/kube-vip settle.
