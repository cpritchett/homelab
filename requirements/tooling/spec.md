# Tooling Requirements
**Effective:** 2025-12-21

## Standard tooling stack

This repo uses a standardized tooling stack for automation, dependency management, and security.

### Task runner
- **Tool:** [Task](https://taskfile.dev) (task.dev)
- **Purpose:** Makefile replacement, cross-platform task automation
- **Config:** `Taskfile.yml` at repo root
- **Usage:** Common operations (bootstrap, validate, deploy, test, lint)

### Version management
- **Tool:** [mise](https://mise.jdx.dev)
- **Purpose:** Pin tool versions (kubectl, talosctl, flux, helm, etc.)
- **Config:** `.mise.toml` at repo root
- **Benefit:** Eliminates "works on my machine" issues

### JavaScript/TypeScript tooling (optional)
- **Tool:** [bun](https://bun.sh)
- **Purpose:** Fast runtime and package manager
- **Config:** `package.json` where JS/TS is needed
- **Scope:** Scripts, utilities, node-based tooling

### Policy enforcement
- **Tool:** [Conftest](https://conftest.dev)
- **Purpose:** Test structured configuration (OPA/Rego)
- **Config:** Policies in `policies/repository/*.rego`
- **Usage:** Repository structure validation, pre-deployment checks
- **Installed via:** mise (`.mise.toml`)

- **Tool:** [Kyverno CLI](https://kyverno.io/docs/kyverno-cli/)
- **Purpose:** Test Kubernetes admission policies locally
- **Config:** Policies in `policies/<domain>/*.yaml`
- **Usage:** Policy validation, manifest testing
- **Installed via:** mise (`.mise.toml`)

### Supply chain security
- **Tool:** [Socket.dev](https://socket.dev) (free tier)
- **Purpose:** Dependency scanning and supply chain monitoring
- **Scope:** npm/bun packages
- **Integration:** CI checks via GitHub App or CLI

### YAML templating
- **Tool:** [ytt](https://carvel.dev/ytt/) (Carvel)
- **Purpose:** YAML templating with data values pattern
- **Config:** `talos/templates/` (schema + base template)
- **Usage:** Talos node configuration generation
- **Installed via:** `brew install ytt`
- **See:** [ADR-0013](../../docs/adr/ADR-0013-ytt-data-values.md)

## Installation requirements

### Minimum (required)
```bash
# Task
brew install go-task/tap/go-task

# mise
curl https://mise.run | sh

# ytt (Talos templating)
brew install ytt
```

### Optional
```bash
# bun (for JS/TS tooling)
curl -fsSL https://bun.sh/install | bash
```

## Prohibitions

Agents and developers MUST NOT:
- Add Makefile when Task can be used
- Install tools globally without pinning versions in `.mise.toml`
- Add npm dependencies without Socket.dev scanning
- Install policy tools (conftest, kyverno) via brew/curl in scripts
- Use ad-hoc bash for policy enforcement when Conftest/Kyverno appropriate

## Policy tool selection

| Use Case | Tool | Rationale |
|----------|------|----------|
| Kubernetes resource policies | Kyverno | Native K8s admission control, rich K8s resource matching |
| Repository structure policies | Conftest (OPA/Rego) | Filesystem/JSON validation, no K8s dependency |
| Infrastructure-as-code policies | Conftest (OPA/Rego) | General-purpose, works with any structured data |
| Ad-hoc validation scripts | **Prohibited** | Use Conftest with Rego policy instead |

**Principle:** Policy logic MUST be declarative (Rego/Kyverno YAML), not imperative (bash).

## Rationale

Standardized tooling reduces friction and "works on my machine" issues. Task provides better UX than Make, mise pins tool versions, and Socket.dev provides free supply chain visibility.

See: [ADR-0008: Developer Tooling Stack](../../docs/adr/ADR-0008-developer-tooling-stack.md)
