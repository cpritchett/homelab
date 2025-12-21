# Talos Configuration Templating Analysis

**Date:** 2025-12-20  
**Scope:** `talos/static-configs/` (home01-home05)  
**Status:** Analysis Complete → Implementation In Progress (ADR-0011)

**Related Documents:**
- [ADR-0011: ytt for Talos Templating](./adr/ADR-0011-talos-ytt-templating.md) — Templating tool selection and rationale
- [talos/FIELD-CLASSIFICATION.md](../talos/FIELD-CLASSIFICATION.md) — Exhaustive field-by-field analysis
- [talos/render.sh](../talos/render.sh) — Rendering orchestration script

## Executive Summary

This analysis examines five legacy Talos machine configurations (four active, one decommissioned) to identify patterns for safe templating. These configs originated from **experimental iteration** ("throwing things at the wall") rather than systematic design, so **best practices must outweigh current patterns** unless documented otherwise.

The active cluster consists of heterogeneous commodity hardware with significant variation in networking, storage, and workload capabilities. A validation-first templating strategy is implemented: verify configurations against Talos documentation, clean up experimental drift, then template the validated state.

**Decision:** **ytt (YAML Templating Tool)** chosen as templating engine per [ADR-0011](./adr/ADR-0011-talos-ytt-templating.md). Architecture: `templates/base.yaml` → `hardware/{type}.yaml` → `nodes/{node}.yaml` → `rendered/{node}.yaml`.

**Key Finding:** Despite hardware heterogeneity and experimental origins, the cluster has converged on strong structural invariants in Kubernetes and Talos core configuration. Documented variations are validated and preserved; undocumented drift is cleaned up per governance principle (best practices > legacy patterns).

## Critical Context: Experimental Origins

⚠️ **These configurations were developed experimentally, not systematically designed.**

Implications for templating:
- **Do NOT assume current patterns are correct** - many variations may be trial-and-error artifacts
- **Validate against Talos documentation** - best practices trump "what's currently there"
- **Undocumented drift is suspect** - treat as bug until proven intentional
- **Comments/governance records trump analysis** - if no documentation exists for a variation, research proper approach
- **Cleanup before templating** - don't enshrine experimental mistakes

## Cluster Context

### Hardware Inventory (from `talos/node-mapping.yaml` and configs)

| Node | IP | Type | RAM | Notable Hardware | Status |
|------|------------|------|-----|------------------|--------|
| home01 | 10.0.5.215 | EQ12 | 32GB | Dual igc NICs (QuickSync gen 12) | ✅ Active |
| home02 | 10.0.5.220 | EQ12 | 32GB | Dual igc NICs (QuickSync gen 12) | ✅ Active |
| home03 | 10.0.5.100 | NUC7 | 32GB | Single igb NIC (QuickSync gen 7) | 🚫 **Decommissioned** |
| home04 | 10.0.5.92 | P520 | 128GB | Dual 10GbE, NVIDIA P2000 GPU | ✅ Active |
| home05 | 10.0.5.129 | ITX | 64GB | Mixed e1000e + igb NICs (QuickSync gen 7) | ✅ Active |

All active nodes are control plane (`type: controlplane`) with scheduling enabled (`allowSchedulingOnControlPlanes: true`).

## Category 1: Structural Invariants

These fields are **identical across all nodes** and represent cluster-wide decisions. These should become the immutable base of any template.

### 1.1 Talos API Configuration

**Files:** All configs  
**Risk Level:** 🔴 CRITICAL - Changes break cluster access

```yaml
version: v1alpha1
debug: false
persist: true
```

### 1.2 Machine PKI (1Password References)

**Files:** All configs  
**Risk Level:** 🔴 CRITICAL - Changes break authentication

```yaml
machine:
  token: op://homelab/talos/MACHINE_TOKEN
  ca:
    crt: op://homelab/talos/MACHINE_CA_CRT
    key: op://homelab/talos/MACHINE_CA_KEY
```

### 1.3 Cluster PKI (1Password References)

**Files:** All configs  
**Risk Level:** 🔴 CRITICAL - Changes break cluster

```yaml
cluster:
  ca:
    crt: op://homelab/talos/CLUSTER_CA_CRT
    key: op://homelab/talos/CLUSTER_CA_KEY
  id: op://homelab/talos/CLUSTER_ID
  secret: op://homelab/talos/CLUSTER_SECRET
  token: op://homelab/talos/CLUSTER_TOKEN
  aggregatorCA:
    crt: op://homelab/talos/CLUSTER_AGGREGATORCA_CRT
    key: op://homelab/talos/CLUSTER_AGGREGATORCA_KEY
  etcd:
    ca:
      crt: op://homelab/talos/CLUSTER_ETCD_CA_CRT
      key: op://homelab/talos/CLUSTER_ETCD_CA_KEY
  serviceAccount:
    key: op://homelab/talos/CLUSTER_SERVICEACCOUNT_KEY
  secretboxEncryptionSecret: op://homelab/talos/CLUSTER_SECRETBOXENCRYPTIONSECRET
```

### 1.4 Certificate SANs (Cluster Identity)

**Files:** All configs except home05  
**Risk Level:** 🟡 HIGH - Affects cluster API reachability

```yaml
machine:
  certSANs:
    - "homeops.hypyr.space"
    - "home01.hypyr.space"
    - "home02.hypyr.space"
    - "home03.hypyr.space"
    - "home04.hypyr.space"
    - "home01"
    - "home02"
    - "home03"
    - "home04"
```

**⚠️ DRIFT DETECTED:** `home05` includes `home05.hypyr.space` and `home05` in its certSANs, others do not. **Cause unknown** - could be intentional evolution of practice, copy-paste error, or timing-related. Requires human review to determine if older nodes should be updated to match home05's pattern.

### 1.5 Feature Gates

**Files:** All configs  
**Risk Level:** 🟡 HIGH - Affects cluster behavior

```yaml
machine:
  features:
    rbac: true
    stableHostname: true
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles: ["os:admin"]
      allowedKubernetesNamespaces: ["actions-runner-system", "system-upgrade"]
    apidCheckExtKeyUsage: true
    diskQuotaSupport: true
    kubePrism:
      enabled: true
      port: 7445
    hostDNS:
      enabled: true
      resolveMemberNames: true
      forwardKubeDNSToHost: false
```

### 1.6 Containerd Configuration

**Files:** All configs  
**Risk Level:** 🟢 MEDIUM - Runtime behavior

```yaml
machine:
  files:
    - op: create
      path: /etc/cri/conf.d/20-customization.part
      content: |
        [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
        [plugins."io.containerd.cri.v1.runtime"]
          device_ownership_from_security_context = true
```

### 1.7 NFS Mount Configuration

**Files:** All configs  
**Risk Level:** 🟢 MEDIUM - Affects NAS connectivity

```yaml
machine:
  files:
    - op: overwrite
      path: /etc/nfsmount.conf
      permissions: 0o644
      content: |
        [ NFSMount_Global_Options ]
        nfsvers=4.1
        hard=True
        nconnect=8
        noatime=True
        rsize=1048576
        wsize=1048576
```

### 1.8 Kernel Modules

**Files:** All configs  
**Risk Level:** 🟢 MEDIUM - Required for Longhorn

```yaml
machine:
  kernel:
    modules:
      - name: nbd
```

### 1.9 Kubelet Base Configuration

**Files:** All configs  
**Risk Level:** 🟡 HIGH - Affects scheduling and eviction

```yaml
machine:
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.34.2
    extraConfig:
      featureGates:
        KubeletSeparateDiskGC: true
      evictionHard:
        "imagefs.available": "5%"
        "nodefs.available": "5%"
      evictionMinimumReclaim:
        "imagefs.available": "10%"
        "nodefs.available": "10%"
    defaultRuntimeSeccompProfileEnabled: true
    nodeIP:
      validSubnets: ["10.0.5.0/24"]
    disableManifestsDirectory: true
```

### 1.10 Network Common Configuration

**Files:** All configs  
**Risk Level:** 🟡 HIGH - Affects name resolution

```yaml
machine:
  network:
    nameservers: ["10.0.5.1"]
    disableSearchDomain: true
```

### 1.11 Shared Sysctls (Network Optimization)

**Files:** All configs  
**Risk Level:** 🟢 MEDIUM - Performance tuning

```yaml
machine:
  sysctls:
    fs.inotify.max_user_watches: 1048576 # Watchdog
    fs.inotify.max_user_instances: 8192 # Watchdog
    net.ipv4.tcp_fastopen: 3 # TCP optimization
    user.max_user_namespaces: 11255 # User namespaces
```

**Note:** Additional sysctls vary by hardware (see Section 2.5).

### 1.12 Time Synchronization

**Files:** All configs  
**Risk Level:** 🔴 CRITICAL - Required for etcd

```yaml
machine:
  time:
    disabled: false
    servers: ["time.cloudflare.com"]
```

### 1.13 Cluster Identity

**Files:** All configs  
**Risk Level:** 🔴 CRITICAL - Cluster name and endpoint

```yaml
cluster:
  clusterName: homeops
  controlPlane:
    endpoint: https://homeops.hypyr.space:6443
```

### 1.14 Cluster Discovery

**Files:** All configs  
**Risk Level:** 🟡 HIGH - Affects node joining

```yaml
cluster:
  discovery:
    enabled: true
    registries:
      kubernetes:
        disabled: true
      service:
        disabled: false
```

### 1.15 Network Configuration (Cluster-wide)

**Files:** All configs  
**Risk Level:** 🔴 CRITICAL - Pod/Service CIDRs

```yaml
cluster:
  network:
    cni:
      name: none
    dnsDomain: cluster.local
    podSubnets: ["10.244.0.0/16"]
    serviceSubnets: ["10.96.0.0/12"]
```

### 1.16 Control Plane Configuration

**Files:** All configs  
**Risk Level:** 🟡 HIGH - Core Kubernetes components

```yaml
cluster:
  allowSchedulingOnControlPlanes: true
  apiServer:
    image: registry.k8s.io/kube-apiserver:v1.34.2
    extraArgs:
      enable-aggregator-routing: true
      bind-address: 0.0.0.0
    certSANs: ["homeops.hypyr.space"]
    disablePodSecurityPolicy: true
  controllerManager:
    image: registry.k8s.io/kube-controller-manager:v1.34.2
    extraArgs:
      bind-address: 0.0.0.0
  coreDNS:
    disabled: true
  etcd:
    advertisedSubnets: ["10.0.5.0/24"]
    extraArgs:
      listen-metrics-urls: http://0.0.0.0:2381
  proxy:
    disabled: true
    image: registry.k8s.io/kube-proxy:v1.34.2
```

### 1.17 Scheduler Configuration

**Files:** All configs  
**Risk Level:** 🟡 HIGH - Pod scheduling behavior

```yaml
cluster:
  scheduler:
    image: registry.k8s.io/kube-scheduler:v1.34.2
    extraArgs:
      bind-address: 0.0.0.0
    config:
      apiVersion: kubescheduler.config.k8s.io/v1
      kind: KubeSchedulerConfiguration
      profiles:
        - schedulerName: default-scheduler
          plugins:
            score:
              disabled:
                - name: ImageLocality
          pluginConfig:
            - name: PodTopologySpread
              args:
                defaultingType: List
                defaultConstraints:
                  - maxSkew: 1
                    topologyKey: kubernetes.io/hostname
                    whenUnsatisfiable: ScheduleAnyway
```

### 1.18 Extra Manifests

**Files:** All configs  
**Risk Level:** 🟡 HIGH - Bootstrap CRDs

```yaml
cluster:
  extraManifests:
    # renovate: datasource=github-releases depName=kubernetes-sigs/gateway-api
    - https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/experimental-install.yaml
    # renovate: datasource=github-releases depName=prometheus-operator/prometheus-operator
    - https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.87.0/stripped-down-crds.yaml
```

### 1.19 Volume Configurations (Shared Pattern)

**Files:** All configs  
**Risk Level:** 🟢 MEDIUM - Local storage provisioning

All nodes define `EPHEMERAL` and `local-storage` volumes with similar selectors (disk transport variations documented in Section 3.2).

### 1.20 Ethernet Ring Buffers

**Files:** All configs  
**Risk Level:** 🟢 MEDIUM - Network performance

```yaml
rings:
  rx: 4096
  tx: 4096
```

Applied to all NICs across all nodes.

## Category 2: Systematic Parameters

These fields **vary predictably** per node and are prime candidates for parameterization.

### 2.1 Network Identity (Per-Node)

**Risk Level:** 🔴 CRITICAL - Must be unique

| Parameter | Type | Example |
|-----------|------|---------|
| `machine.network.hostname` | FQDN | `home01.hypyr.space` |
| `machine.network.interfaces[0].addresses[0]` | CIDR | `10.0.5.215/24` |

**Validation:** Hostname must match IP in `talos/node-mapping.yaml`.

### 2.2 Hardware-Specific Bonding/Bridging

**Risk Level:** 🟡 HIGH - Node-specific, hardware-dependent

| Node | Config Type | Devices | Status |
|------|-------------|---------|--------|
| home01 | bond (802.3ad) | Hardware selector: `7c:83:34:*`, driver `igc` | Active |
| home02 | bond (802.3ad) | Hardware selector: `7c:83:34:*`, driver `igc` | Active |
| home03 | bridge (bond0) | Single interface: `eno1` | **Decommissioned** |
| home04 | bond (802.3ad) | Explicit interfaces: `enp23s0f1np1`, `enp23s0f0np0` | Active |
| home05 | bond (802.3ad) | PCI selectors by driver (`e1000e`, `igb`) | Active |

**Anti-Pattern:** Do NOT template NIC device selection. This is hardware-specific and errors cause boot failure.

### 2.3 VLAN Configuration (Consistent Across Nodes)

**Risk Level:** 🟡 HIGH - Must match infrastructure

```yaml
vlans:
  - { vlanId: 10, dhcp: false, mtu: 1500 }  # IoT network (Multus)
  - vlanId: 48                                # LoadBalancer IPs (Cilium)
    dhcp: false
    mtu: 1500
```

Present on all nodes. This is an invariant, not a parameter.

### 2.4 Node Labels (Workload Scheduling)

**Risk Level:** 🟢 MEDIUM - Affects scheduling only

Common labels (all nodes):
```yaml
topology.kubernetes.io/region: k8s
topology.kubernetes.io/zone: main-smc
```

Variable labels:

| Node | quicksync.generation | postgres.priority | Other | Status |
|------|----------------------|-------------------|-------|--------|
| home01 | "12" | fallback | - | Active |
| home02 | "12" | fallback | - | Active |
| home03 | "7" | disabled | - | **Decommissioned** |
| home04 | - | preferred | - | Active |
| home05 | "7" | preferred | `node.kubernetes.io/instance-type: itx` | Active |

**Parameterization Strategy:** Labels should be externalized to a per-node data file (e.g., YAML/JSON) referencing hardware capabilities from `talos/node-mapping.yaml`.

### 2.5 Sysctl Variations (Hardware-Specific)

**Risk Level:** 🟡 HIGH - Resource allocation

#### Common to home01, home02 (and formerly home03):
```yaml
net.core.rmem_max: 67108864 # 10Gb/s
net.core.wmem_max: 67108864 # 10Gb/s
net.ipv4.tcp_congestion_control: bbr
sunrpc.tcp_slot_table_entries: 128
sunrpc.tcp_max_slot_table_entries: 128
vm.nr_hugepages: 1024 # PostgreSQL (standard nodes)
```

#### home04 (P520 - High Memory):
```yaml
net.core.rmem_max: 67108864
net.core.wmem_max: 67108864
net.ipv4.tcp_congestion_control: bbr
sunrpc.tcp_slot_table_entries: 128
sunrpc.tcp_max_slot_table_entries: 128
vm.nr_hugepages: 8192 # 16GB hugepages (128GB RAM)
vm.max_map_count: 2097152 # AI/ML workloads
kernel.pid_max: 262144
vm.swappiness: 1
```

#### home05 (ITX - Medium Memory):
```yaml
vm.nr_hugepages: 4096 # 8GB hugepages (64GB RAM)
vm.max_map_count: 1048576
vm.swappiness: 10
# Note: Missing net.core.rmem/wmem_max and sunrpc settings
```

**⚠️ DRIFT DETECTED:** home05 is missing several sysctls present in other nodes. This may be intentional (hardware differences) or accidental drift.

**Anti-Pattern:** Do NOT template sysctls naively. These are tuned for specific RAM/workload profiles.

### 2.6 Kubelet Resource Reservations

**Risk Level:** 🟡 HIGH - Affects schedulable capacity

| Node | systemReserved.cpu | systemReserved.memory | kubeReserved.cpu | kubeReserved.memory | Status |
|------|--------------------|-----------------------|------------------|---------------------|--------|
| home01 | - | - | - | - | Active |
| home02 | - | - | - | - | Active |
| home03 | - | - | - | - | Decommissioned |
| home04 | 2000m | 8Gi | 2000m | 8Gi | Active |
| home05 | 1000m | 4Gi | 1000m | 4Gi | Active |

**Parameterization Strategy:** Reservations should be calculated based on node RAM class (low: none, medium: 4Gi, high: 8Gi).

## Category 3: Anti-Patterns (Do NOT Template)

These represent **intentional differences** or **hardware reality** that must remain static.

### 3.1 Talos Factory Images

**Risk Level:** 🔴 CRITICAL - Hardware-specific system extensions

| Node | Factory Image Hash | Extensions | Status |
|------|-------------------|------------|--------|
| home01 | `b12c79d1a286...` | EQ12: i915, intel-ucode, nfsd | Active |
| home02 | `b12c79d1a286...` | EQ12: i915, intel-ucode, nfsd | Active |
| home03 | `b12c79d1a286...` | NUC7: i915, intel-ucode, nfsd | Decommissioned |
| home04 | `d38be64a0b19...` | P520: i915, intel-ucode, nfsd, **mei** | Active |
| home05 | `b12c79d1a286...` | ITX: i915, intel-ucode, nfsd | Active |

**Why This Matters:** Factory images are immutable references to Talos installer images with baked-in kernel modules. The P520 requires the `mei` (Management Engine Interface) extension; others do not. Changing these requires regenerating images via `schematics/*.yaml` and Talos image factory.

**Anti-Pattern:** Do NOT parameterize `machine.install.image`. This must be explicitly set per hardware type.

### 3.2 Install Disk Paths

**Risk Level:** 🔴 CRITICAL - Hardware-specific, breaks boot

| Node | Disk Path | Status |
|------|-----------|--------|
| home01 | `/dev/sda` | Active |
| home02 | `/dev/sda` | Active |
| home03 | `/dev/sda` | Decommissioned |
| home04 | `/dev/disk/by-id/ata-WDC_WDS500G2B0A_20096X468305` | Active |
| home05 | `/dev/sda` | Active |

**Why home04 is Different:** P520 has multiple disks; absolute device path ensures correct system disk.

**Anti-Pattern:** Do NOT template disk paths. These are discovered during initial install and must not change.

### 3.3 Extra Kernel Args (home03 Only)

**File:** [home03.yaml](../talos/static-configs/home03.yaml#L78)  
**Risk Level:** 🟢 LOW - Currently unused

```yaml
machine:
  install:
    extraKernelArgs: []
```

Only home03 declares this (empty). Likely added during troubleshooting and left in place.

**Anti-Pattern:** Do NOT propagate empty declarations to other configs. Keep configs minimal.

### 3.4 User Volume Disk Selectors

**Risk Level:** 🟡 HIGH - Hardware-specific

| Node | Selector | Status |
|------|----------|--------|
| home01 | `system_disk && disk.transport == "sata"` | Active |
| home02 | `system_disk && disk.transport == "sata"` | Active |
| home03 | `system_disk && disk.transport == "sata"` | Decommissioned |
| home04 | `disk.wwid == "naa.5001b444a74ca49f"` (specific NVMe) | Active |
| home05 | `system_disk && disk.transport == "sata"` | Active |

**Why home04 is Different:** Multi-disk system with separate fast NVMe for local storage.

**Anti-Pattern:** Do NOT assume uniform storage. Per-node storage inventory required.

### 3.5 Ethernet Device Names

**Risk Level:** 🔴 CRITICAL - Kernel naming conventions

| Node | Devices | Status |
|------|---------|--------|
| home01 | `enp1s0`, `enp2s0` | Active |
| home02 | `enp1s0`, `enp2s0` | Active |
| home03 | `eno1` | Decommissioned |
| home04 | `enp23s0f1np1`, `enp23s0f0np0` | Active |
| home05 | `eno1`, `enp2s0` | Active |

**Anti-Pattern:** Do NOT infer device names. These are kernel-assigned based on PCI topology.

## Detected Drift (Likely Experimental Artifacts)

**Analysis Approach:** Given the experimental origins, all drift should be **validated against Talos best practices** before templating. The sections below identify variations that may be:
- Experimental mistakes to fix
- Evolving understanding of best practices
- Legitimate hardware-specific requirements

**Default Stance:** When in doubt, consult Talos documentation and test, rather than preserving current state.

### Drift 1: home05 certSANs Inclusion

**Location:** [home05.yaml](../talos/static-configs/home05.yaml#L10-L19)  
**Nature:** **Unknown** - no evidence to determine if intentional or accidental  
**Possibilities:**
- Evolving practice (should update home01-home04 to include themselves)
- Copy-paste error (should remove from home05)
- Timing artifact (home05 added later, others pre-date this pattern)

**Action Required:** Human review needed. Questions to answer:
- Does each node need its own hostname in certSANs for Talos API access?
- Should all nodes be standardized to include themselves?
- What was the original intent of the certSANs list?

**Risk:** If templated incorrectly, could affect Talos API reachability on specific nodes.

### Drift 2: home05 Missing Sysctls

**Location:** [home05.yaml](../talos/static-configs/home05.yaml#L107-L113)  
**Missing:**
- `net.core.rmem_max`
- `net.core.wmem_max`
- `net.ipv4.tcp_congestion_control`
- `sunrpc.tcp_slot_table_entries`
- `sunrpc.tcp_max_slot_table_entries`

**Nature:** Possibly accidental. These sysctls are present in all other nodes.  
**Recommendation:** Investigate if intentional (different NIC capabilities) or oversight. If oversight, add in controlled update.

### Drift 3: home03 extraKernelArgs Declaration

**Location:** [home03.yaml](../talos/static-configs/home03.yaml#L78)  
**Nature:** Likely leftover from debugging  
**Action:** Remove (node is decommissioned, so only relevant if pattern appears elsewhere).

### Drift 4: Inconsistent Resource Reservations (Likely Missing Best Practice)

**Location:** home01, home02 have no kubelet reservations; home04, home05 do  
**Nature:** Probably experimental - some nodes added reservations, others never updated  
**Best Practice:** All nodes should reserve resources for system/kubelet based on capacity  
**Action Required:**
- Research Talos/Kubernetes recommended reservation formulas
- Apply consistently based on node RAM class
- Don't template "no reservations" as if it's a valid configuration

### Drift 5: home04 Unique Sysctls (Validate if Hardware-Specific)

**Location:** [home04.yaml](../talos/static-configs/home04.yaml#L119-L124)  
**Unique Sysctls:**
- `vm.max_map_count: 2097152` (vs 1048576 on home05)
- `kernel.pid_max: 262144` (not present on others)
- `vm.swappiness: 1` (vs 10 on home05)

**Nature:** May be AI/ML workload tuning, or experimental settings that weren't propagated  
**Action Required:**
- Validate if these are appropriate for GPU/high-memory nodes
- If yes, codify in "high-mem-ai" profile with rationale
- If no, standardize across appropriate RAM classes

### Drift 6: home05 Missing Network Sysctls (Likely Accidental)

**Already documented above, but emphasizing:** This is almost certainly an **omission**, not a deliberate choice. home05 likely should have the same network tuning as home01/home02.

### Drift 7: Inconsistent Node Labels (Workload vs Hardware)

**Observation:** Labels mix hardware facts (`quicksync.generation`) with workload scheduling (`postgres.priority`)
**Issue:** Hardware facts are immutable; workload scheduling should be mutable and managed separately
**Action Required:**
- Separate hardware labels (derived from node-mapping) from workload labels
- Hardware labels: read-only, templated from inventory
- Workload labels: mutable, managed via GitOps policy or external label controller

### Phase 0: Validation Against Best Practices (CRITICAL)

**Goal:** Don't template experimental mistakes. Validate current configs against Talos documentation first.

**Tasks:**
- [ ] Research Talos certSANs best practices (should nodes include themselves?)
- [ ] Research kubelet resource reservation recommendations
- [ ] Validate sysctl settings against Talos performance tuning docs
- [ ] Identify which variations are hardware-specific vs experimental drift
- [ ] Document findings in ADR before proceeding

**Output:** "Canonical Configuration Specification" - what SHOULD be configured, not just what IS configured

### Phase 1: Shared Base (Invariants)

**Goal:** Extract cluster-wide invariants into a single base template.

**Structure:**
```
talos/
  templates/
    base-invariants.yaml.tmpl   # All Category 1 invariants
  data/
    node-parameters.yaml         # Per-node data (IPs, hostnames, hardware IDs)
    cluster-versions.yaml        # Kubernetes/Talos versions (renovate-managed)
```

**Example `node-parameters.yaml`:**
```yaml
nodes:
  home01:
    hostname: home01.hypyr.space
    ip: 10.0.5.215
    hardware_type: EQ12
    ram_class: low  # low: <64GB, medium: 64GB, high: >64GB
    nics:
      bond0:
        mode: hardware_selector
        selector: { hardwareAddr: "7c:83:34:*", driver: igc }
    labels:
      quicksync.generation: "12"
      postgres.priority: fallback
  # ... (home02, home04, home05 - home03 is decommissioned)
```

### Phase 2: Hardware Profiles

**Goal:** Codify hardware-specific configuration without losing safety.

**Structure:**
```
talos/
  profiles/
    networking/
      bond-igc-dual.yaml       # home01, home02
      bridge-single.yaml       # (decommissioned: home03)
      bond-explicit.yaml       # home04
      bond-pci-selector.yaml   # home05
    storage/
      sata-default.yaml        # home01, home02, home05 (formerly home03)
      nvme-wwid.yaml           # home04
    resources/
      low-mem.yaml             # home01, home02 (formerly home03)
      high-mem-ai.yaml         # home04
      medium-mem.yaml          # home05
```

Each profile is a fragment containing ONLY the hardware-specific section.

### Phase 3: Rendering Pipeline

**Goal:** Generate static configs from templates + data with human-readable diffs.

**Tool Selection Criteria:**
- Must produce deterministic output (Git-friendly)
- Must support 1Password reference pass-through (`op://...` must not be interpolated)
- Must support inline comments (preserve intent documentation)
- Must support validation against Talos schema

**Options (No Decision Yet):**
- **ytt:** Good YAML preservation, learning curve
- **Jsonnet:** Powerful, JSON-based (loses YAML comments)
- **Gomplate:** Simple, file-based, good 1Password integration
- **Custom Go tool:** Maximum control, maintenance burden

**Recommended:** Start with **gomplate** for simplicity, revisit if complexity grows.

### Phase 4: Directory Structure (Future State)

```
talos/
  static-configs/          # UNCHANGED - historical record
    home01.yaml
    home02.yaml
    ...
  
  templates/               # NEW - source of truth after migration
    base.yaml.tmpl
    profiles/
      networking/
      storage/
      resources/
  
  data/                    # NEW - parameter inventory
    cluster-versions.yaml  # Renovate-managed
    node-parameters.yaml   # Manual/scripted
  
  rendered/                # NEW - generated configs (Git-tracked)
    home01.yaml
    home02.yaml
    ...
  
  schematics/              # UNCHANGED
  node-mapping.yaml        # UNCHANGED - source of truth for IPs
```

## Migration Plan (Phased Approach)

### Phase 0A: Current State Documentation
- [ ] Document current cluster state snapshot
- [ ] Verify all configs apply successfully with `talosctl validate`
- [ ] Create ADR documenting this analysis and migration intent

### Phase 0B: Validation & Cleanup (DO NOT SKIP)
- [ ] Research Talos best practices for all identified drift areas
- [ ] Document intended configuration in ADR (what SHOULD be, not what IS)
- [ ] Create cleanup plan for experimental drift
- [ ] Test cleanup changes on one node, validate stability
- [ ] Apply cleanup to all nodes BEFORE templating
- [ ] Duration: 2-4 weeks (research + careful testing)

### Phase 0C: Template Preparation
- [ ] Add CI check: rendered configs must match current (post-cleanup) configs (byte-for-byte)

### Phase 1: Base Template (Low Risk)
- [ ] Extract Category 1 invariants to `templates/base.yaml.tmpl`
- [ ] Render configs for all nodes
- [ ] Verify byte-for-byte match with `static-configs/`
- [ ] Duration: 1-2 weeks (validation period)

### Phase 2: Add Parameterization (Medium Risk)
- [ ] Add `data/node-parameters.yaml` with Category 2 parameters
- [ ] Update template to interpolate hostnames, IPs
- [ ] Render and verify byte-for-byte match
- [ ] Duration: 2-3 weeks

### Phase 3: Hardware Profiles (Higher Risk)
- [ ] Create profile fragments for networking/storage/resources
- [ ] Update render process to merge profiles
- [ ] Render and verify byte-for-byte match
- [ ] Duration: 3-4 weeks

### Phase 4: Cutover (Authoritative Source Change)
- [ ] Update documentation: templates are now source of truth
- [ ] Archive `static-configs/` to `static-configs.archive/`
- [ ] Rename `rendered/` to `static-configs/`
- [ ] Update CI/CD to use templates
- [ ] Duration: 1 week

### Phase 5: First Live Update (Validation)
- [ ] Update Kubernetes version in `cluster-versions.yaml`
- [ ] Render new configs
- [ ] Apply to home01 or home02 (EQ12 nodes with QuickSync but standard workloads)
- [ ] Wait 1 week, monitor
- [ ] If successful, apply to remaining nodes (home04 last due to GPU/AI workloads)
- [ ] Duration: 4-6 weeks (staged rollout)

**Note:** Originally planned to test on home03 (lowest-risk: no Ceph, standard hardware), but this node has been permanently decommissioned.

**Total Timeline:** 3-4 months from start to full adoption

## Validation Strategy

### Pre-Apply Validation
1. **Schema validation:** `talosctl validate --config <rendered-config.yaml>`
2. **Diff review:** Human inspection of diff between old and new configs
3. **Secret references:** Verify all `op://...` references intact
4. **IP uniqueness:** Automated check for duplicate IPs
5. **Hostname consistency:** Cross-check with `node-mapping.yaml`

### Post-Apply Validation
1. **Node health:** `talosctl health --nodes <node>`
2. **Etcd health:** `talosctl etcd status`
3. **Kubernetes health:** `kubectl get nodes`, `kubectl get pods -A`
4. **Service continuity:** Verify workload scheduling unchanged
5. **Storage I/O:** Verify Longhorn/NFS still functional

## Risk Mitigation

### Risk 1: Factory Image Mismatch
**Scenario:** Template error generates wrong factory image for node  
**Impact:** 🔴 Node fails to boot  
**Mitigation:**
- Maintain `factory_image` as explicit per-node parameter (no inference)
- CI check: factory image must match schematic for node's hardware type
- Always test on non-critical node first (home03)

### Risk 2: Network Configuration Typo
**Scenario:** Wrong IP or NIC selector in parameters  
**Impact:** 🔴 Node loses network, requires console access  
**Mitigation:**
- CI validation: IP must be in `10.0.5.0/24`, no duplicates
- Pre-apply: dry-run with `talosctl apply-config --dry-run`
- Always have IPMI/console access ready
- Test on home01 or home02 first (standard EQ12 hardware with fallback Postgres priority)

### Risk 3: Template Logic Error
**Scenario:** Conditional rendering produces invalid YAML  
**Impact:** 🟡 Deployment blocked by validation  
**Mitigation:**
- Byte-for-byte match testing in CI before any live apply
- Lint templates with yamllint + Talos schema validation
- Keep template logic minimal (prefer explicit profiles over clever conditionals)
- Validate against all 4 active node configs (home01, home02, home04, home05)

### Risk 4: Drift Reintroduction
**Scenario:** Manual edit to rendered config bypasses template  
**Impact:** 🟢 Config drift, future renders overwrite manual change  
**Mitigation:*Standardization:** Should all nodes include their own hostname in certSANs?
   - **Current State:** home01-home04 do NOT include themselves; home05 DOES include itself
   - **Investigation Needed:** 
     - Does Talos require node's own hostname in certSANs for local API access?
     - Was home05 correct to add itself, or was this an error?
     - Test: Does removing home05's self-reference break anything?
   - **Recommendation:** Research Talos best practices, test on non-production, then standardize all nodes
- Document: ALL changes must go through templates

## Open Questions

1. **Sysctl Standardization:** Should home05 be updated to include missing network sysctls, or is the difference intentional due to NIC capabilities?
   - **Recommendation:** Test adding sysctls to home05, monitor for issues. If stable, standardize.

2. **certSANs Future Nodes:** Should all new nodes be added to certSANs on all machines?
   - **Current:** Only home05 has self in SANs
   - **Recommendation:** Add all current nodes to base template, add new nodes to SANs on next Talos upgrade.

3. **Renovate Integration:** How should `cluster-versions.yaml` integrate with Renovate for automated K8s/Talos upgrades?
   - **Recommendation:** Renovate updates `cluster-versions.yaml`, CI renders and tests, PR requires manual approval before apply.

4. **Node Addition Workflow:** What's the process for adding home06?
   - **Recommendation:** 
     1. Add entry to `node-parameters.yaml`
     2. Add to `node-mapping.yaml`
     3. Render config
     4. Validate, then apply
     5. If successful, add to certSANs in `base.yaml.tmpl` and re-render all configs

5. **Emergency Rollback:** If a template change causes cluster issues, what's the recovery path?
   - **Recommendation:** Keep `static-configs.archive/` immutable. In emergency, revert to known-good archived configs.

## Conclusion

The Talos configuration set is **feasible for templating** but requires **validation before preservation**. These configs evolved experimentally, so patterns may reflect trial-and-error rather than best practices.

### Success Factors:
1. **Strong invariants exist:** Cluster-wide settings are mostly consistent
2. **Isolated variance:** Hardware-specific config is identifiable
3. **Historical record:** Current configs provide baseline for comparison
4. **Governance framework:** Constitution/contracts provide decision criteria

### Critical Prerequisites:
1. **Validate before templating:** Research Talos best practices for all drift areas
2. **Clean up first:** Fix experimental mistakes BEFORE enshrining in templates
3. **Document decisions:** Every variation needs rationale (ADR or inline comments)
4. **Test carefully:** Networking and disk paths are unforgiving

### Primary Risk: **Templating Experimental Mistakes**

If we template current state without validation, we:
- Enshrine accidental configurations as "patterns"
- Make it harder to adopt best practices later
- Propagate bugs to future nodes

### Primary Benefit: **Systematic Version Management**

Once validated and templated:
- Centralized Kubernetes/Talos version management
- Renovate-driven upgrades
- Consistent application of best practices
- Hardware-specific tuning preserved where legitimate

### Recommendation: **Validate First, Template Second**

**DO NOT proceed directly to Phase 1 (template extraction).** Instead:

1. **Phase 0B (Validation):** Research best practices, document intended state
2. **Apply cleanup:** Fix drift on live nodes, validate stability
3. **THEN template:** Once configs represent best practices, not experiments

**Timeline:** Add 2-4 weeks for validation phase. This is NOT optional - templating without validation will create technical debt.

## References

- [ADR-0007: Commodity Hardware Constraints](adr/ADR-0007-commodity-hardware-constraints.md)
- [Talos Configuration Reference](https://www.talos.dev/latest/reference/configuration/)
- [Talos Image Factory](https://factory.talos.dev/)
- Governance: [constitution/constitution.md](../constitution/constitution.md)
- Hardware Mapping: [talos/node-mapping.yaml](../talos/node-mapping.yaml)
- Schematics: [talos/schematics/](../talos/schematics/)
