# ADR-0011: ytt for Talos Configuration Templating

## Status
**Superseded by [ADR-0012](ADR-0012-talos-native-patching.md)**

> **Note:** This ADR documents the initial decision to use ytt. During implementation,
> ytt's overlay model was found incompatible with Talos's single-document merge
> requirements. See ADR-0012 for the replacement decision using `talosctl machineconfig patch`.

## Context
Talos cluster configuration is currently static per-node in `talos/static-configs/`, with significant duplication across 4 nodes (home01, home02, home04, home05). Nodes share:
- All cluster-wide configuration (Kubernetes version, API server flags, CNI settings, etc.)
- Hardware-specific settings (NIC bonding, kernel modules, kubelet resources per RAM class)
- Per-node parameters (hostname, IP address, workload labels)

### Current problems
- **Drift:** Different nodes have inconsistent sysctls, kubelet settings, and network configuration (some by accident)
- **Version upgrades:** Single Kubernetes version change requires modifying 4 files and careful merging
- **Maintainability:** 90% of each config is identical; changes are error-prone and non-obvious

### Templating requirements
Talos configuration must:
1. **Preserve YAML exactly** — Comments, structure, order must survive templating
2. **Never interpolate 1Password references** — `op://...` must pass through unchanged for CLI evaluation
3. **Support multi-layer composition** — Base → Hardware → Node without string manipulation
4. **Fail safely** — Explicit over implicit; no inference for hardware facts (factory images, disk paths, NIC names)
5. **Be deterministic** — Same inputs always produce identical outputs
6. **Not require cluster access** — CI/local rendering must work offline

## Decision

**Adopt ytt (YAML Templating Tool) from Carvel project** as the sole templating system for Talos configuration.

### Architecture
```
templates/base.yaml          # All cluster-wide invariants
  ↓
hardware/{eq12,p520,itx}.yaml  # Hardware-specific profiles
  ↓
nodes/{home01-05}.yaml         # Per-node parameters
  ↓
rendered/{home01-05}.yaml      # Final config (Git-tracked)
```

### Reasoning
ytt is chosen over alternatives because:

1. **YAML-native:** Preserves comments, ordering, and structure via overlay/merge operators (`#@overlay`)
   - Alternative (Helm) uses Go templates, mangles YAML structure
   - Alternative (Kustomize) relies on strategic merge patches, opaque transformations
   - Alternative (gomplate) is string-based, loses YAML context

2. **No interpolation:** Uses data values and overlays, not string substitution
   - 1Password references (`op://homelab/talos/...`) pass through unchanged
   - No accidental variable expansion in comments or strings

3. **Deterministic:** Generated output is byte-for-byte reproducible
   - Same templates + inputs = identical output (testable in CI)
   - No randomization or ordering surprises

4. **Explicit hardware detection:** Forces explicit device selectors, factory images, disk paths
   - No inference; errors are caught immediately
   - NIC device names must be explicit per hardware type (failure = network loss)

5. **Lightweight:** Single Go binary, no cluster access, runs anywhere
   - Local development: `ytt -f templates/ ... > out.yaml`
   - CI: Lint and render without Kubernetes API
   - Offline safe: No network calls or external dependencies

### Rejected alternatives

#### Helm
- **Pros:** Large ecosystem, mature, widely known
- **Cons:**
  - Go template syntax mangles YAML (comments, ordering lost)
  - String-based variable substitution breaks 1Password refs
  - Overly complex (Helm charts, repos, releases) for single-cluster case
  - Heavy dependency on cluster access for some operations

#### Kustomize
- **Pros:** K8s-native, simple for basic overlays
- **Cons:**
  - Strategic merge patches are opaque (unclear what changed)
  - YAML structure mangling via JSON patches
  - Limited composition: can't overlay multiple inheritance levels cleanly
  - No good answer for handling comments and exact YAML preservation

#### gomplate
- **Pros:** Lightweight, flexible templating
- **Cons:**
  - String-based templating (loses YAML context)
  - 1Password refs would require escaping/special handling
  - Determinism not guaranteed (Go template randomization)
  - Not YAML-aware (no overlay/merge operators)

#### Ansible/Jinja2
- **Pros:** Familiar to ops teams
- **Cons:**
  - Adds dependency on Ansible (not present in cluster)
  - String-based templating, same YAML mangling issues
  - Harder to run in CI without full Ansible installation

### Configuration structure

**Base template** (`templates/base.yaml`):
- All cluster-wide settings (Kubernetes version, API config, kubelet defaults, CNI settings)
- Invariant labels (topology zones)
- Network configuration (subnets, DNS, routes)
- 1Password secret references (literal strings, never evaluated)
- ~450 lines, 40% comments explaining *why* each setting exists

**Hardware profiles** (`hardware/{eq12,p520,itx}.yaml`):
- Factory image hash (specific to hardware)
- NIC device selectors (MAC prefix + driver, hardware-specific)
- Kubelet resource reservations (scaled by RAM class)
- Sysctls (network tuning, memory settings per hardware)
- Hardware labels (QuickSync generation, GPU presence)
- ~150-200 lines each

**Node files** (`nodes/{home01-05}.yaml`):
- Hostname and FQDN
- IP address and routes
- Install disk path (explicit, never inferred)
- Workload labels (mutable, managed separately from hardware facts)
- ~50-70 lines each

**Rendered outputs** (`rendered/{home01-05}.yaml`):
- Generated by `./talos/render.sh`
- Git-tracked for human review and rollback safety
- CI validates: `rendered output ≡ ytt(templates + hardware + node)`

### Rendering process
```bash
#!/usr/bin/env bash
ytt \
  -f templates/base.yaml \
  -f hardware/${HARDWARE_TYPE}.yaml \
  -f nodes/${NODE}.yaml \
  > rendered/${NODE}.yaml
```

Safety checks:
- Verify ytt syntax is valid
- Verify 1Password refs are intact (count `op://` occurrences)
- Validate against talosctl schema (if available)

### Validation strategy

**Pre-commit:**
- Lint templates with `ytt --lint`
- Render all nodes, verify syntax

**PR validation:**
- Render all nodes
- Byte-for-byte comparison with previous render
- Flag unexpected diffs (may indicate unintended changes)

**Live deployment:**
- Render node config
- Apply via talosctl (Talos validates against schema)
- Monitor for unexpected behavior

### Operational model

**Version upgrades:**
1. Change Kubernetes version in `templates/base.yaml`
2. Run `./render.sh all`
3. Review diffs (should be version number only)
4. Commit rendered configs
5. Apply one node at a time, monitor

**Adding a new node:**
1. Add hardware type (if new) to `hardware/`
2. Create `nodes/new-node.yaml` with IP, hostname, disk
3. Run `./render.sh new-node`
4. Review, commit, apply

**Hardware-specific settings:**
1. Are they in `hardware/`? (NIC names, resource reservations, sysctls)
2. Are they in `nodes/`? (workload labels, IP address, disk path)
3. Are they in `templates/base.yaml`? (cluster-wide invariants only)

### Constraints and guardrails

**What agents MUST NOT do:**
1. Modify `talos/static-configs/*.yaml` (legacy archive)
2. Infer factory images, disk paths, or NIC names (must be explicit)
3. Interpolate 1Password references (must pass through)
4. Template `base.yaml` without ADR review (cluster-wide changes)
5. Mass-edit hardware profiles (these are hardware facts, not policy)

**What agents CAN do:**
1. Update versions in `base.yaml` (Talos, Kubernetes)
2. Add/modify workload labels in `nodes/`
3. Render configs via `ytt` and `render.sh`
4. Run validation (lint, syntax checks)

**What agents SHOULD ask about:**
1. Adding new sysctls
2. Changing network configuration
3. Modifying kubelet settings
4. Adding hardware-specific defaults

## Consequences

### Positive
- Single source of truth for cluster configuration
- Easy to track configuration changes via Git diffs
- Version upgrades become mechanical (one-line changes)
- Explicit hardware detection prevents boot failures
- 1Password integration works seamlessly (refs pass through)
- Rendered outputs are auditable and reviewable

### Negative
- New tool (ytt) to learn; not as widely known as Helm/Kustomize
- Overlay syntax takes getting used to
- Pre-commit must run `ytt` to validate (minor friction)

### Mitigation
- Document patterns in comments (40% of base.yaml is comments)
- Provide examples (`nodes/home01.yaml` as reference)
- Create runbook for common operations (version upgrade, add node)
- CI validates all renders automatically

## References
- [ytt Documentation](https://carvel.dev/ytt/)
- [ytt Overlay Documentation](https://carvel.dev/ytt/docs/v0.45.x/lang-ref-ytt-overlay/)
- [Talos Configuration Reference](https://www.talos.dev/v1.11/reference/configuration/)
- ADR-0007: Commodity Hardware Constraints
- ADR-0010: Longhorn for Non-Database Storage
- Document: `docs/talos-templating-analysis.md`
- Document: `talos/FIELD-CLASSIFICATION.md`
- Script: `talos/render.sh`
