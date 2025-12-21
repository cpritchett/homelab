# ADR-0009: Git Workflow and Commit Conventions

## Status
Accepted

## Context
Repository needs standardized git workflow to ensure traceability, review quality, and governance compliance. Conventional Commits provide structured commit messages that enable automation and clear changelog generation.

## Decision

### Branch strategy
- **Main branch:** `main` (protected, requires PR)
- **Feature branches:** `feat/<scope>/<short-description>`
- **Fix branches:** `fix/<scope>/<short-description>`
- **Docs branches:** `docs/<scope>/<short-description>`
- **Chore branches:** `chore/<scope>/<short-description>`

**Scope examples:** `dns`, `ingress`, `compute`, `tooling`, `governance`, `adr`

### Commit message format (Conventional Commits)
```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature or capability
- `fix`: Bug fix
- `docs`: Documentation changes
- `chore`: Maintenance (deps, tooling, CI)
- `refactor`: Code restructuring without behavior change
- `test`: Test additions or modifications
- `ci`: CI/CD changes

**Scope (required):** Domain or area affected (e.g., `dns`, `ingress`, `compute`, `governance`)

**Examples:**
```
feat(dns): add ExternalDNS internal/external policy support

fix(ingress): correct WAN bandwidth constraint in spec

docs(adr): add ADR-0009 for git workflow

chore(tooling): pin kubectl version in mise config
```

### Pull request workflow
1. Create feature branch from `main`
2. Make changes with conventional commits
3. Open PR with descriptive title (conventional commit format)
4. Complete PR template checklist
5. Wait for CI checks and review
6. Squash merge to `main` (preserves conventional commit format)

### Labels
**Auto-applied by path** (via `.github/labeler.yml`):
- `constitution` - Changes to constitutional docs
- `contracts` - Changes to contracts/invariants/hard-stops
- `requirements` - Changes to domain specs
- `adr` - Changes to ADRs
- `docs` - Documentation changes
- `infra` - Infrastructure code
- `ops` - Operational content

**Manual labels:**
- `breaking` - Breaking changes requiring migration
- `security` - Security-related changes
- `dependencies` - Dependency updates

### Issue labels
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `governance` - Constitutional/contract changes
- `question` - Further information requested
- `wontfix` - Will not be worked on

## Consequences

**Benefits:**
- Conventional commits enable automated changelog generation
- Clear commit history aids debugging and auditing
- Branch naming enforces scope discipline
- PR templates ensure governance compliance checks
- Auto-labeling reduces manual overhead

**Constraints:**
- Developers must follow conventional commit format
- PRs required for all changes (no direct commits to `main`)
- Scope must be included in commit messages

**Tooling:**
- `commitlint` (optional) can enforce conventional commit format
- GitHub Actions can validate commit messages in CI

## Links
- [Conventional Commits specification](https://www.conventionalcommits.org/)
- [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md)
- [.github/labeler.yml](../../.github/labeler.yml)
