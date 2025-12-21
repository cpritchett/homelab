# ADR-0013: ytt Data Values for Talos Templating (Supersedes ADR-0011, ADR-0012)

## Status
Accepted

## Context

### ADR-0011: ytt Overlays — Failed
Selected ytt overlays for Talos configuration templating. Failed because ytt overlays are designed for Kubernetes manifests (multiple independent documents). When using multiple overlay files, each produces its own merged document instead of combining into a single Talos configuration.

### ADR-0012: talosctl machineconfig patch — Failed
Attempted to use Talos's native `talosctl machineconfig patch` command. Failed because it **validates the configuration during patching**, which causes base64 decode errors on 1Password `op://` references. The command cannot process configs with placeholder secrets.

### Evaluation Criteria
After both failures, we evaluated alternatives based on:
1. **Minimal external scripting** — Prefer out-of-box tool usage
2. **Low ongoing maintenance** — Standard patterns, good documentation
3. **Works with `op://` references** — No validation during templating
4. **Single output document** — Talos requires merged config

## Decision

**Use ytt with Data Values pattern** as the Talos configuration templating system.

This is ytt's primary, canonical usage pattern—not overlays. Data values separate configuration data from templates, allowing:
- Templates to use `#@ data.values.xxx` for variable substitution
- Node-specific values provided via `--data-values-file`
- Hardware-specific settings conditionally included based on `data.values.hardware_type`
- Single merged output document

### Why Data Values Over Overlays

| Aspect | ytt Overlays | ytt Data Values |
|--------|--------------|-----------------|
| **Designed for** | Patching existing K8s manifests | Generating configs from templates |
| **Multiple files** | Each produces separate document | All merge into single output |
| **Variable data** | Embedded in overlay structure | Separate data files |
| **Complexity** | High (overlay/match semantics) | Low (simple variable substitution) |
| **ytt documentation** | Secondary pattern | Primary pattern |

### Architecture

```
talos/
├── templates/
│   ├── schema.yaml           # Data values schema (validation)
│   ├── base.yaml             # Main template (uses data.values)
│   ├── hardware/
│   │   ├── _helpers.yaml     # Hardware selection logic
│   │   ├── eq12.yaml         # EQ12-specific config fragments
│   │   ├── p520.yaml         # P520-specific config fragments
│   │   └── itx.yaml          # ITX-specific config fragments
│   └── volumes/
│       └── volume-configs.yaml  # VolumeConfig, EthernetConfig docs
├── values/
│   ├── home01.yaml           # Node data values
│   ├── home02.yaml
│   ├── home04.yaml
│   └── home05.yaml
├── rendered/
│   └── *.yaml                # Generated configs (Git-tracked)
└── render.sh                 # Simple wrapper (optional)
```

### Node Values File Example

Node files contain only data—no ytt directives needed:

```yaml
#@data/values
---
# Node identity
hostname: home01.hypyr.space
ip_address: 10.0.5.215/24
gateway: 10.0.5.1

# Hardware selection
hardware_type: eq12  # Selects EQ12-specific settings

# Install configuration  
install_disk: /dev/sda

# Workload labels
postgres_priority: fallback
topology_zone: main-smc
```

### Template Usage Example

Templates use `#@ data.values.xxx` for substitution:

```yaml
#@ load("@ytt:data", "data")

machine:
  network:
    hostname: #@ data.values.hostname
    interfaces:
      - interface: bond0
        addresses:
          - #@ data.values.ip_address
        routes:
          - network: "0.0.0.0/0"
            gateway: #@ data.values.gateway
  install:
    disk: #@ data.values.install_disk
```

### Render Command

Single ytt command per node:

```bash
ytt -f templates/ --data-values-file values/home01.yaml > rendered/home01.yaml
```

Or with optional wrapper script:

```bash
./render.sh home01      # Render single node
./render.sh all         # Render all nodes
```

### Hardware Selection

Hardware-specific settings are conditionally included based on `data.values.hardware_type`:

```yaml
#@ load("@ytt:data", "data")

#@ if data.values.hardware_type == "eq12":
machine:
  install:
    image: factory.talos.dev/metal-installer/b12c79d1a286...:v1.11.0-rc.0
  kubelet:
    extraConfig:
      systemReserved:
        cpu: "500m"
        memory: "2Gi"
#@ end
```

## Consequences

### Positive

1. **Out-of-box ytt usage** — This is ytt's canonical pattern, well-documented
2. **Single output document** — Templates merge correctly into one config
3. **Works with `op://` references** — No validation during templating
4. **Schema validation** — ytt validates data values against schema
5. **Clear separation** — Data (values/) vs templates (templates/)
6. **Simple node files** — Just YAML data, no ytt syntax required
7. **Minimal scripting** — Single ytt command, optional wrapper

### Negative

1. **Template restructure required** — Must rewrite templates to use data.values
2. **Conditional logic in templates** — Hardware selection uses `#@ if` blocks
3. **Learning curve** — Data values + starlark syntax

### Trade-offs Accepted

- More upfront restructuring work, but simpler long-term maintenance
- Templates are more verbose (explicit conditionals), but behavior is clearer
- Hardware selection is explicit (`#@ if`) rather than implicit (overlay matching)

## References

- [ytt Data Values documentation](https://carvel.dev/ytt/docs/latest/ytt-data-values/)
- [ytt Schema documentation](https://carvel.dev/ytt/docs/latest/ytt-schema/)
- ADR-0011: ytt for Talos Configuration Templating (superseded — overlay approach failed)
- ADR-0012: Talos Native Patching (superseded — talosctl patch failed with op:// refs)
- ADR-0007: Commodity Hardware Constraints
