# ADR-0012: Talos Native Patching (Supersedes ADR-0011)

## Status
**Superseded by [ADR-0013](ADR-0013-ytt-data-values.md)**

> **Note:** This ADR attempted to use `talosctl machineconfig patch` for config templating.
> Implementation failed because talosctl validates configs during patching, which causes
> base64 decode errors on 1Password `op://` references. See ADR-0013 for the final solution
> using ytt data values.

## Context

ADR-0011 selected ytt (YAML Templating Tool) for Talos configuration templating. During implementation, we discovered a fundamental incompatibility:

### The Problem

ytt's overlay system produces **multiple YAML documents** when applying overlays from separate files:

```yaml
# Expected (single merged document):
machine:
  install:
    disk: /dev/sda
    image: factory.talos.dev/...
  network:
    hostname: home01.hypyr.space

# Actual ytt output (multiple documents):
machine:
  install:
    image: factory.talos.dev/...
---
machine:
  network:
    hostname: home01.hypyr.space
---
machine:
  install:
    disk: /dev/sda
```

When `talosctl validate` processes this output, it fails with "unknown keys found during decoding" because multiple `machine:` keys appear as separate documents rather than being deep-merged.

### Root Cause

ytt overlays are designed for Kubernetes manifests (multiple independent documents). They apply `#@overlay/match` against all documents, producing new merged documents for each overlay file. Talos configuration requires a **single merged document** with proper deep-merge semantics.

### Attempted Workarounds

1. **Single overlay file:** Would defeat the layered architecture (base → hardware → node)
2. **ytt data values + template:** Requires restructuring all templates, loses the "partial config" simplicity
3. **Post-process merge:** Additional tool, fragile, non-obvious

## Decision

**Replace ytt with `talosctl machineconfig patch`** as the sole templating system for Talos configuration.

### Why talosctl machineconfig patch

Talos includes native configuration patching with **strategic merge patch** semantics, specifically designed for Talos config:

```bash
talosctl machineconfig patch base.yaml \
  --patch @patches/hardware/eq12.yaml \
  --patch @patches/nodes/home01.yaml \
  -o rendered/home01.yaml
```

### Benefits Over ytt

1. **Purpose-built:** Designed by Siderolabs specifically for Talos configuration merging
2. **Strategic merge semantics:** Proper deep merge with smart list handling:
   - `network.interfaces` merges on `interface:` or `deviceSelector:` key
   - `network.interfaces.vlans` merges on `vlanId:` key
   - Arrays append by default (configurable)
3. **Multi-document support:** Correctly handles VolumeConfig, EthernetConfig, UserVolumeConfig
4. **No external dependencies:** Uses talosctl, already required for cluster operations
5. **Patches are pure YAML:** No special syntax, just partial configs
6. **Delete support:** `$patch: delete` for removing sections

### Architecture

```
talos/
├── base.yaml                 # Full base configuration
├── patches/
│   ├── hardware/
│   │   ├── eq12.yaml        # Strategic merge patch
│   │   ├── p520.yaml
│   │   └── itx.yaml
│   └── nodes/
│       ├── home01.yaml      # Strategic merge patch  
│       ├── home02.yaml
│       ├── home04.yaml
│       └── home05.yaml
├── rendered/
│   ├── home01.yaml          # Final merged config
│   └── ...
└── render.sh                 # Uses talosctl machineconfig patch
```

### Rendering Process

```bash
#!/usr/bin/env bash
NODE="home01"
HARDWARE_TYPE="eq12"  # Mapped from node name

talosctl machineconfig patch base.yaml \
  --patch @patches/hardware/${HARDWARE_TYPE}.yaml \
  --patch @patches/nodes/${NODE}.yaml \
  -o rendered/${NODE}.yaml
```

Patches apply in order: hardware first, then node. Later patches override earlier ones.

## Alternatives Considered

### ytt (ADR-0011) — REJECTED
- **Pros:** YAML-native, preserves comments, explicit overlays
- **Cons:** Overlay model incompatible with Talos single-document merge requirement
- **Outcome:** Produces invalid multi-document output

### ytt with Data Values — REJECTED
- **Pros:** Could work with restructured templates
- **Cons:** Requires moving from "partial config" to "variable substitution" model; loses simplicity; significant rework
- **Outcome:** Complexity increase without benefit over native patching

### Kustomize — REJECTED
- **Pros:** Widely known, K8s-native
- **Cons:** Strategic merge patches are JSON-based internally; less Talos-aware; comments lost
- **Outcome:** talosctl's native patching is more appropriate

### yq merge — REJECTED  
- **Pros:** Simple tool, widely available
- **Cons:** Basic merge (no strategic semantics); interface/VLAN merging requires custom logic
- **Outcome:** Would need custom wrapper for Talos-specific merge rules

### gomplate / Jinja2 — REJECTED (from ADR-0011)
- String-based templating loses YAML context
- 1Password refs require escaping
- Not suitable for config composition

## Consequences

### Positive
- **Native tooling:** No additional dependencies beyond talosctl
- **Correct semantics:** Talos-aware strategic merge (interfaces, VLANs, etc.)
- **Simpler patches:** Pure YAML without overlay directives
- **Multi-document support:** VolumeConfig, EthernetConfig work correctly
- **Validated output:** talosctl understands Talos schema during patching

### Negative
- **ADR-0011 superseded:** ytt work must be refactored (minimal: remove overlay directives)
- **Less widely known:** talosctl patching less documented than ytt
- **Talos version dependency:** Patch semantics may evolve with Talos versions

### Migration

1. Remove ytt overlay directives from hardware and node files
2. Move templates/base.yaml → base.yaml (already plain YAML)
3. Rename directories: hardware/ → patches/hardware/, nodes/ → patches/nodes/
4. Update render.sh to use talosctl machineconfig patch
5. Re-render all nodes and validate

### Guardrails (Unchanged from ADR-0011)

**Agents MUST NOT:**
1. Modify `talos/static-configs/*.yaml` (legacy archive)
2. Infer factory images, disk paths, or NIC names
3. Interpolate 1Password references
4. Modify base.yaml without ADR review

**Agents CAN:**
1. Update versions in base.yaml
2. Add/modify workload labels in patches/nodes/
3. Render configs via render.sh
4. Run validation

## References
- [Talos Configuration Patching](https://docs.siderolabs.com/talos/v1.9/configure-your-talos-cluster/system-configuration/patching)
- [Strategic Merge Patch Semantics](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-api-machinery/strategic-merge-patch.md)
- ADR-0011: ytt for Talos Configuration Templating (superseded)
- ADR-0007: Commodity Hardware Constraints
- ADR-0010: Longhorn for Non-Database Storage
