# Renovate Configuration

This directory contains modular Renovate Bot configuration files that customize how dependency updates are handled in this repository.

## Configuration Structure

### Core Files

- **`semanticCommits.json5`** — Defines the semantic commit format and PR body templates
  - Enables conventional commits with proper scoping
  - Enriches PR bodies with release notes, changelogs, and package links
  - Ensures compatibility with release-please for automated releases

- **`packageRules.json5`** — Dependency-specific rules and scoping
  - Configures semantic commit scopes by dependency type (docker, ci, tools, etc.)
  - Sets update policies (major/minor/patch release ages, approval requirements)
  - Defines file match patterns for different managers

- **`groups.json5`** — Grouped updates for related components
  - Groups related dependencies (e.g., Media Stack, Monitoring, Authentik)
  - Applies domain-specific scopes (media, monitoring, auth, ingress, database, etc.)
  - Reduces PR noise by bundling related updates

### Other Configuration Files

- **`allowedVersions.json5`** — Version constraints for specific packages
- **`autoMerge.json5`** — Auto-merge rules (extended from remote config)
- **`customManagers.json5`** — Custom regex managers for non-standard dependency formats
  - Annotated YAML dependencies (`datasource=... depName=...` comments)
  - mise.toml tool versions (opentofu, conftest, task)
- **`grafanaDashboards.json5`** — Grafana dashboard update rules (extended from remote config)
- **`labels.json5`** — PR label configuration (extended from remote config)

## Managed Formats

- **Docker Compose** — Primary format; matches `stacks/**/compose.yaml` and `ansible/**/compose.yaml`
- **GitHub Actions** — Workflow files in `.github/workflows/`
- **mise.toml** — Tool version management via custom regex managers
- **Annotated YAML** — Any YAML file with `datasource=... depName=...` comments

## Semantic Commit Scopes

Renovate is configured to use the following semantic commit scopes to categorize updates:

### Stack-Specific Scopes (Release-Please Integration)
These scopes match the packages defined in `.github/release-please-config.json` to ensure proper version tagging:
- `op-export` — op-export stack dependencies (stacks/platform/secrets/op-export)
- `forgejo-stack` — Forgejo stack dependencies (stacks/platform/cicd/forgejo)
- `woodpecker-stack` — Woodpecker stack dependencies (stacks/platform/cicd/woodpecker)
- `backstage` — Backstage application dependencies

### General Dependencies
- `deps` — Default scope for general dependencies
- `dev-deps` — Development dependencies

### Infrastructure Components
- `docker` — Docker image updates
- `ci` — GitHub Actions and CI tool updates
- `tools` — CLI tools from mise.toml

### Grouped Updates (Domain-Specific)
- `monitoring` — Prometheus, Grafana, Loki, Alloy, and observability stack
- `media` — Sonarr, Radarr, Prowlarr, Plex, qBittorrent, and media services
- `auth` — Authentik SSO
- `ingress` — Caddy reverse proxy
- `database` — PostgreSQL
- `dns` — Cloudflare and cloudflared tunnel
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
# Stack-specific updates (for release-please tagging)
chore(op-export): update op-export stack
chore(forgejo-stack): update forgejo stack
chore(woodpecker-stack): update woodpecker stack
chore(backstage): update backstage dependencies

# Docker Compose image updates
chore(docker): update Docker image lscr.io/linuxserver/sonarr to v4.0.14
chore(media): update Media Stack group
chore(monitoring): update Monitoring Stack group
chore(auth): update Authentik group

# CI and tooling
chore(ci): update GitHub Action checkout to v4
chore(tools): update tool opentofu/opentofu
chore(deps): update conftest to v0.66.0
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
