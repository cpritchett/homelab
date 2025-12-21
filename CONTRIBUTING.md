# Contributing to hypyr homelab

## Git workflow

All contributions must follow the standardized git workflow.

### Branch naming
```
<type>/<scope>/<short-description>
```

**Types:** `feat`, `fix`, `docs`, `chore`  
**Scopes:** `dns`, `ingress`, `compute`, `tooling`, `governance`, `adr`, etc.

**Examples:**
- `feat/dns/externaldns-support`
- `fix/ingress/bandwidth-spec`
- `docs/adr/git-workflow`

### Commit messages (Conventional Commits)
```
<type>(<scope>): <subject>

[optional body]
```

**Required:** Type, scope, and subject  
**Format:** Imperative mood, lowercase, no trailing period

**Examples:**
```
feat(dns): add ExternalDNS internal/external policy support
fix(ingress): correct WAN bandwidth constraint in spec
docs(adr): add ADR-0009 for git workflow
chore(tooling): pin kubectl version in mise config
```

### Pull requests

1. **Create feature branch** from `main`
2. **Commit with conventional format** (scope required)
3. **Open PR** with conventional commit title
4. **Complete PR template** checklist
5. **Wait for CI** checks and reviews
6. **Squash merge** to `main`

**PR title format:**
```
<type>(<scope>): <description>
```

### Labels

Labels are auto-applied based on changed paths (see `.github/labeler.yml`):
- `constitution`, `contracts`, `requirements` - Governance changes
- `adr`, `docs` - Documentation
- `infra`, `ops` - Implementation

**Manual labels:**
- `breaking` - Breaking changes
- `security` - Security-related
- `governance` - Policy changes

## Governance changes

Changes to `constitution/`, `contracts/`, or `requirements/` require:
1. ADR documenting the decision
2. Risk assessment if applicable
3. PR template checklist completion
4. Constitutional compliance verification

See [requirements/workflow/spec.md](requirements/workflow/spec.md) for full requirements.

## Questions?

Open an issue with the `question` label.
