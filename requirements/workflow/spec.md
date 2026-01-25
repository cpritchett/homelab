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

## Agent Governance Steering

**Principle:** Agents must reference canonical governance sources rather than hardcoding rules. This enables governance to evolve without requiring agent code changes.

### Canonical Authority Hierarchy

Agents MUST consult these documents in order:

1. **`constitution/constitution.md`** — Immutable principles (highest authority)
   - Amendment process
   - ADR lifecycle
   - Contract definition and lifecycle

2. **`constitution/amendments/`** — Constitutional amendments
   - Amendment-level procedures (e.g., contract lifecycle)

3. **`contracts/`** — Operating rules and constraints
   - `agents.md` — Agent behavioral rules and allowed/prohibited actions
   - `invariants.md` — System invariants (what must always be true)
   - `hard-stops.md` — Actions requiring human approval

4. **`requirements/workflow/spec.md`** (this file) — Agent governance steering
   - How agents reference canonical sources
   - Which governance documents to consult
   - Where agent instructions should live

5. **`requirements/**/spec.md`** — Domain specifications
   - Domain-specific requirements and constraints

6. **`docs/adr/`** — Architectural decision records
   - Rationale for governance decisions
   - Linked from relevant specs

7. **`docs/governance/procedures.md`** — Procedural documentation
   - Workflows and change procedures
   - Examples and decision trees

### Agent Instruction Governance

Agent instructions MUST:
- Live in **canonical governance documents only** (constitution, contracts, requirements, docs)
- Reference this hierarchy when describing governance rules
- NOT create new instruction files (`.md` files that duplicate governance)
- Update automatically when canonical sources change (without requiring code edits)

Agent instruction files that are **prohibited**:
- `CLAUDE.md` - use this spec + canonical sources instead
- `.gemini` - use this spec + canonical sources instead
- Any other role-specific instruction grab bags

**Approved agent instruction locations:**
- `.github/copilot-instructions.md` — Copilot-specific tool guidance (if needed); MUST link to canonical sources
- `.github/agents/*.agent.md` — Speckit agent files; MUST include "## Governance Authority" section

### Adding Agent Instructions

**When to add agent instructions:**
- Only if copilot/tooling-specific guidance is needed (e.g., VS Code API details)
- Must link to canonical governance sources
- Must be in approved locations only

**Prohibited:**
- Creating new role-specific instruction files
- Duplicating governance rules from canonical sources
- Hardcoding governance procedures that should come from specs

**Validation:** CI gate `check-no-agent-grab-bag.sh` blocks commits with unapproved agent instruction files.

## Prohibitions

Agents and developers MUST NOT:
- Commit directly to `main` branch
- Use non-conventional commit messages
- Omit scope from commit messages
- Merge PRs without completing checklist
- Create agent instruction files outside approved locations
- Duplicate governance rules from canonical sources in agent instructions

## Rationale

Conventional commits enable automation (changelog, semantic versioning) and provide clear commit history. Branch protection and PR workflow ensure governance compliance and peer review.

See: [ADR-0009: Git Workflow and Commit Conventions](../../docs/adr/ADR-0009-git-workflow-conventions.md)
See: [ADR-0017: Talos Bare-Metal Bootstrap Procedure](../../docs/adr/ADR-0017-talos-baremetal-bootstrap.md)
See: [ADR-0018: GitOps Structure Refactor for home-ops](../../docs/adr/ADR-0018-gitops-structure-refactor.md)
See: [ADR-0020: Bootstrap, Storage, and Repository Governance Codification](../../docs/adr/ADR-0020-bootstrap-storage-governance-codification.md)
See: [ADR-0022: Komodo-Managed NAS Stacks (supersedes ADR-0021)](../../docs/adr/ADR-0022-truenas-komodo-stacks.md)
See: [ADR-0021: Require Registry for NAS Stacks (superseded)](../../docs/adr/ADR-0021-stacks-registry-required.md)
See: [ADR-0023: Scripts and Stacks Directory Classification](../../docs/adr/ADR-0023-scripts-stacks-classification.md)
See: [ADR-0024: Speckit Workflow for Non-Canonical Implementation](../../docs/adr/ADR-0024-speckit-workflow-non-canonical.md)
See: [ADR-0026: Spec Placement Governance](../../docs/adr/ADR-0026-spec-placement-governance.md)
See: [ADR-0025: Strict Markdown Governance](../../docs/adr/ADR-0025-strict-markdown-governance.md)
See: [ADR-0027: Agent PR/Issue Template Enforcement](../../docs/adr/ADR-0027-agent-template-enforcement.md)
See: [ADR-0028: Constitutional Authority for Governance Procedures](../../docs/adr/ADR-0028-constitutional-governance-authority.md)
See: [ADR-0029: Contract Lifecycle Procedures](../../docs/adr/ADR-0029-contract-lifecycle-procedures.md)
See: [ADR-0030: Agent Governance Steering Pattern](../../docs/adr/ADR-0030-agent-governance-steering.md)
