# Talos Configuration Templating System

**Status:** Active  
**Tool:** ytt (Data Values pattern)  
**Last Updated:** 2025-12-21

## Overview

This directory contains a **template-driven configuration system** for Talos Kubernetes nodes. Instead of maintaining separate static configs for each node, we use ytt data values to compose shared configuration with hardware-specific and node-specific parameters.

### Philosophy

- **Explicit over implicit:** No inference for hardware facts (factory images, disk paths, NIC names)
- **Fail-closed:** Schema validation catches errors immediately
- **Auditable:** Git history shows exact configuration changes
- **Maintainable:** Version upgrades become single-line changes in `templates/base.yaml`

## Directory Structure

```
talos/
├── templates/
│   ├── schema.yaml            Data values schema (validation)
│   └── base.yaml              Main template with #@ data.values
│
├── values/
│   ├── home01.yaml            Node data: hostname, IP, hardware_type
│   ├── home02.yaml
│   ├── home04.yaml
│   └── home05.yaml
│
├── rendered/                  Generated output (.gitignored)
│
├── schematics/                Hardware definitions (factory image specs)
│   ├── EQ12.yaml              Extensions: i915, intel-ucode, nfsd, open-iscsi
│   ├── P520.yaml              Extensions: ^^ + mei
│   ├── ITX.yaml               Extensions: ^^ (without mei)
│   └── NUC7.yaml              Legacy reference
│
├── render.sh                  ytt wrapper script
├── node-mapping.yaml          Node to hardware type mapping
└── README.md                  This file
```

## Quick Start

### Prerequisites

```bash
# Install ytt (once)
brew install ytt
```

### Rendering Configurations

```bash
# Render all nodes
./render.sh all

# Render specific node
./render.sh home01

# Render and validate
./render.sh --validate
```

### Applying to Cluster

Rendered configs contain `op://` 1Password references. Use 1Password CLI to inject secrets:

```bash
# Render
./render.sh home01

# Inject secrets and apply
op run -- talosctl apply-config \
  --nodes 10.0.5.215 \
  --file rendered/home01.yaml
```

## Architecture

### Data Values Pattern

Unlike ytt overlays, data values cleanly separate **data** from **templates**:

```
values/home01.yaml (data)     templates/base.yaml (template)
─────────────────────────     ──────────────────────────────
hostname: home01.hypyr.space  hostname: #@ data.values.hostname
ip_address: 10.0.5.215/24     addresses:
hardware_type: eq12             - #@ data.values.ip_address
```

**Render command:**
```bash
ytt -f templates/ --data-values-file values/home01.yaml
```

### Hardware Types

The `hardware_type` field in values determines hardware-specific configuration:

| Type | Nodes | RAM | Bond Config | Key Features |
|------|-------|-----|-------------|--------------|
| eq12 | home01, home02 | 32GB | deviceSelectors (MAC) | QuickSync 12, VLANs, EthernetConfig |
| p520 | home04 | 128GB | interfaces (explicit) | 8GB hugepages, high sysctls, no VLANs |
| itx | home05 | 64GB | deviceSelectors (PCI) | QuickSync 7, instance-type label |

### Node Values Schema

Each `values/{node}.yaml` must provide:

```yaml
hostname: home01.hypyr.space       # FQDN
ip_address: 10.0.5.215/24          # CIDR notation
gateway: 10.0.5.1                  # Default gateway
hardware_type: eq12                # eq12 | p520 | itx
install_disk: /dev/sda             # Boot disk path
postgres_priority: fallback        # preferred | fallback
topology_region: k8s               # Kubernetes region label
topology_zone: main-smc            # Kubernetes zone label
```

## Common Tasks

### Upgrade Kubernetes Version

1. Edit version in `templates/base.yaml`
2. Render all: `./render.sh all`
3. Apply one node at a time

### Add a New Node

1. Create `values/homeXX.yaml` with node data
2. Add node to `NODES` array in `render.sh`
3. Update `node-mapping.yaml`
4. Render and apply

### Change Hardware Setting

Edit the hardware conditionals in `templates/base.yaml`, render, apply.

## Validation

```bash
# Lint templates
ytt -f templates/ --data-values-file values/home01.yaml > /dev/null

# Render with validation
./render.sh --validate
```

Note: `talosctl validate` cannot be used because it attempts to decode `op://` references as base64.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `ytt: command not found` | `brew install ytt` |
| `render.sh: permission denied` | `chmod +x render.sh` |
| Schema validation error | Check values file against `templates/schema.yaml` |
| Unknown hardware_type | Must be `eq12`, `p520`, or `itx` |

## Decision Log

- **ADR-0011:** Initial ytt overlay approach (superseded)
- **ADR-0012:** talosctl machineconfig patch attempt (superseded)
- **ADR-0013:** ytt data values pattern (current)

See [docs/adr/](../docs/adr/) for full decision records.

## References

- [ADR-0013: ytt Data Values](../docs/adr/ADR-0013-ytt-data-values.md)
- [ADR-0010: Longhorn Storage](../docs/adr/ADR-0010-longhorn-storage.md)
- [ytt Documentation](https://carvel.dev/ytt/)
- [Talos Configuration Reference](https://www.talos.dev/v1.11/reference/configuration/)

