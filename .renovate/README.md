# Renovate Configuration

This directory contains modular Renovate Bot configuration files that customize how dependency updates are handled in this repository.

## Configuration Structure

### Core Files

- **`semanticCommits.json5`** — Defines the semantic commit format and PR body templates
  - Enables conventional commits with proper scoping
  - Enriches PR bodies with release notes, changelogs, and package links
  - Ensures compatibility with release-please for automated releases

- **`packageRules.json5`** — Dependency-specific rules and scoping
  - Configures semantic commit scopes by dependency type (helm, docker, ci, tools, etc.)
  - Sets update policies (major/minor/patch release ages, approval requirements)
  - Defines file match patterns for different managers

- **`groups.json5`** — Grouped updates for related components
  - Groups related dependencies (e.g., Cilium, Kubernetes + Talos, monitoring stack)
  - Applies domain-specific scopes (k8s, networking, monitoring, database, etc.)
  - Reduces PR noise by bundling related updates

### Other Configuration Files

- **`allowedVersions.json5`** — Version constraints for specific packages
- **`autoMerge.json5`** — Auto-merge rules (extended from remote config)
- **`customManagers.json5`** — Custom regex managers for non-standard dependency formats
- **`grafanaDashboards.json5`** — Grafana dashboard update rules (extended from remote config)
- **`labels.json5`** — PR label configuration (extended from remote config)
- **`talosFactory.json5`** — Talos-specific update rules (extended from remote config)

## Semantic Commit Scopes

Renovate is configured to use the following semantic commit scopes to categorize updates:

### General Dependencies
- `deps` — Default scope for general dependencies
- `dev-deps` — Development dependencies

### Infrastructure Components
- `helm` — Helm chart updates
- `docker` — Docker image updates
- `ci` — GitHub Actions and CI tool updates
- `tools` — CLI tools from mise.toml

### Grouped Updates (Domain-Specific)
- `k8s` — Kubernetes and Talos updates
- `networking` — Cilium and network-related components
- `monitoring` — Prometheus, Grafana, and observability stack
- `database` — PostgreSQL and database systems
- `storage` — VolSync and storage solutions
- `dns` — CoreDNS and Cloudflare
- `secrets` — External Secrets Operator
- `gitops` — Flux Operator and GitOps tools
- `registry` — Spegel and container registry components
- `cert-manager` — Certificate management
- `1password` — 1Password Connect
- `home` — Home automation stack (Home Assistant, Zigbee2MQTT, Mosquitto)

## PR Body Format

Renovate PRs include:
- **Package table** — Shows package name, type, update type, change, and pending status
- **Release notes** — Links to release notes if available
- **Package information** — Links to package source, homepage, and repository
- **Changelogs** — Full changelog content when available
- **Warnings and notes** — Important information about the update

## Example PR Titles

```
chore(helm): update Cilium chart to v1.14.0
chore(docker): update nginx image to v1.21.0
chore(ci): update GitHub Action checkout to v4
chore(k8s): update Kubernetes and Talos group
chore(monitoring): update Kube-Prometheus-Stack group
chore(deps): update eslint to v8.0.0
```

## Integration with Release-Please

The semantic commit format ensures that release-please can properly:
- Categorize updates in changelogs
- Determine version bumps (patch/minor/major)
- Generate accurate release notes

See [ADR-0031](../docs/adr/ADR-0031-automated-release-process.md) for more information about the automated release process.

## Validation

To validate the Renovate configuration:

```bash
npx -p renovate renovate-config-validator
```

This checks for syntax errors and validates against the Renovate schema.

## References

- [Renovate Documentation](https://docs.renovatebot.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [ADR-0031: Automated Release Process](../docs/adr/ADR-0031-automated-release-process.md)
