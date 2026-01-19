# Workflow Requirements
**Effective:** 2025-12-21

## Git workflow

All work MUST follow standardized git workflow to ensure traceability and governance compliance.

### Branch requirements

**Protected branches:**
- `main` - Protected, requires PR approval

**Feature branch naming:**
```
<type>/<scope>/<short-description>
```

**Types:**
- `feat/` - New features or capabilities
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `chore/` - Maintenance (deps, tooling, CI)

**Scope examples:** `dns`, `ingress`, `compute`, `tooling`, `governance`, `adr`

**Examples:**
```
feat/dns/externaldns-support
fix/ingress/bandwidth-constraint
docs/adr/git-workflow
chore/tooling/mise-config
```

### Commit message requirements

**Format (Conventional Commits):**
```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Required elements:**
- Type: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`
- Scope: Domain or area (e.g., `dns`, `ingress`, `compute`, `governance`)
- Subject: Imperative mood, lowercase, no period

**Examples:**
```
feat(dns): add ExternalDNS internal/external policy support

fix(ingress): correct WAN bandwidth constraint in spec

docs(adr): add ADR-0009 for git workflow

chore(tooling): pin kubectl version in mise config
```

### Pull request requirements

**Process:**
1. Create feature branch from `main`
2. Commit changes using conventional commit format
3. Open PR with title matching conventional commit format
4. Complete PR template checklist
5. Wait for CI checks and required reviews
6. Squash merge to `main`

**PR title format:**
```
<type>(<scope>): <description>
```

**PR checklist (from template):**
- [ ] Specs impact identified
- [ ] Constitution compliance verified
- [ ] ADR added/updated if changing rules
- [ ] Risk register updated if applicable

### Labeling requirements

**Auto-applied labels** (via `.github/labeler.yml`):
- `constitution` - Changes to `constitution/`
- `contracts` - Changes to `contracts/`
- `requirements` - Changes to `requirements/`
- `adr` - Changes to `docs/adr/`
- `docs` - Changes to `docs/`
- `infra` - Changes to `infra/`
- `ops` - Changes to `ops/`

**Manual labels:**
- `breaking` - Breaking changes
- `security` - Security-related changes
- `governance` - Constitutional/contract changes
- `dependencies` - Dependency updates

**Issue labels:**
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `governance` - Governance changes
- `question` - Further information requested

## Prohibitions

Agents and developers MUST NOT:
- Commit directly to `main` branch
- Use non-conventional commit messages
- Omit scope from commit messages
- Merge PRs without completing checklist

## Rationale

Conventional commits enable automation (changelog, semantic versioning) and provide clear commit history. Branch protection and PR workflow ensure governance compliance and peer review.

See: [ADR-0009: Git Workflow and Commit Conventions](../../docs/adr/ADR-0009-git-workflow-conventions.md)
See: [ADR-0017: Talos Bare-Metal Bootstrap Procedure](../../docs/adr/ADR-0017-talos-baremetal-bootstrap.md)
See: [ADR-0018: GitOps Structure Refactor for home-ops](../../docs/adr/ADR-0018-gitops-structure-refactor.md)
See: [ADR-0020: Bootstrap, Storage, and Repository Governance Codification](../../docs/adr/ADR-0020-bootstrap-storage-governance-codification.md)
See: [ADR-0022: Komodo-Managed NAS Stacks (supersedes ADR-0021)](../../docs/adr/ADR-0022-truenas-komodo-stacks.md)
See: [ADR-0021: Require Registry for NAS Stacks (superseded)](../../docs/adr/ADR-0021-stacks-registry-required.md)
