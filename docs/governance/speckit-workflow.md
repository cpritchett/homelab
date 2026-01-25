# Speckit Workflow for Non-Canonical Implementation

**Effective:** 2026-01-25

This document provides detailed procedures for using the Speckit workflow to plan and execute non-canonical implementation work (stacks, infra, ops).

## Overview

**Speckit** is a lightweight workflow for structured implementation planning. It uses simple templates to document:
- **Requirements** (what must be true)
- **Architecture** (how we'll build it)
- **Tasks** (ordered steps with acceptance criteria)

**Purpose:** Provide consistency and traceability for non-canonical work without ADR overhead.

## When to Use Speckit

### Use Speckit For

✅ **Adding new applications to `/stacks`**
- New platform services (auth, ingress, monitoring)
- Application-tier services (databases, web apps)
- Multi-container stacks with dependencies

✅ **Major infrastructure changes in `/infra`**
- New network segments or VLANs
- Storage system provisioning
- Terraform modules for new resources

✅ **New operational procedures in `/ops`**
- Backup/restore strategies
- Disaster recovery runbooks
- Monitoring and alerting setup

✅ **Non-trivial multi-component work**
- Changes affecting multiple services
- Work requiring architectural decisions
- Implementation where you want clear acceptance criteria

### Skip Speckit For

❌ **Bug fixes within established patterns** - Just fix and document in commit
❌ **Routine updates** - Version bumps, config tweaks, dependency updates
❌ **Documentation-only changes** - Edit docs directly
❌ **Canonical changes** - Use full ADR process instead (see ADR-0005)

### Speckit vs ADR Decision Tree

```
Is this a canonical change (constitution/contracts/requirements)?
├─ YES → Use ADR process (ADR-0005)
└─ NO → Is this non-trivial implementation work?
    ├─ YES → Use Speckit workflow
    └─ NO → Just implement (document in commit message)
```

---

## Workflow Phases

### Phase 1: Constitution Review

**Goal:** Ensure no governance violations before starting.

**Steps:**

1. **Review constitutional principles** ([constitution/constitution.md](../../constitution/constitution.md)):
   - Management is Sacred and Boring
   - DNS Encodes Intent
   - External Access is Identity-Gated
   - Routing Does Not Imply Permission
   - Prefer Structural Safety Over Convention

2. **Check hard-stops** ([contracts/hard-stops.md](../../contracts/hard-stops.md)):
   - Exposing services directly to WAN
   - Publishing `in.hypyr.space` publicly
   - Non-console access to Management
   - Overlay agents on Management VLAN
   - Overriding public FQDN internally

3. **Verify invariants** ([contracts/invariants.md](../../contracts/invariants.md)):
   - Management VLAN: 100, CIDR: 10.0.100.0/24
   - K8s Cluster VLAN: 5, CIDR: 10.0.5.0/24
   - Public zone: hypyr.space
   - Internal zone: in.hypyr.space
   - Storage, hardware, GitOps rules

4. **Check domain requirements** (`requirements/*/spec.md`):
   - Review relevant domain specs (dns, ingress, storage, etc.)
   - Ensure compliance with MUST/MUST NOT/SHOULD rules

**Outcome:** Confidence that work won't violate governance rules.

---

### Phase 2: Specify (Requirements)

**Goal:** Define what must be true for this implementation.

**Template:** [`.specify/templates/spec-template.md`](../../.specify/templates/spec-template.md)

**Location:** Co-locate with implementation
- `stacks/platform/myapp/spec.md`
- `kubernetes/clusters/homelab/myservice/spec.md`
- `infra/mymodule/spec.md`

**Content:**

```markdown
# [Component] Specification

## Overview
<!-- Brief description of what this component does -->

## Requirements

### MUST
<!-- Hard requirements that cannot be violated -->
- Component MUST use encrypted secrets via 1Password
- Component MUST expose metrics on :9090/metrics

### MUST NOT
<!-- Prohibited behaviors -->
- Component MUST NOT store secrets in environment files
- Component MUST NOT expose services directly to WAN

### SHOULD
<!-- Recommendations, deviations require justification -->
- Component SHOULD use pinned image digests (SHA256)
- Component SHOULD implement health checks

## Checks
<!-- Validation criteria - how do we verify requirements? -->
- [ ] Secrets materialized from 1Password
- [ ] Health endpoint returns 200 OK
- [ ] Image digest pinned in compose.yaml

## Links
<!-- Related ADRs, governance specs, documentation -->
- [ADR-0022: Komodo-Managed Stacks](../../docs/adr/ADR-0022-truenas-komodo-stacks.md)
- [Secrets Requirements](../../requirements/secrets/spec.md)
```

**Best Practices:**
- Keep requirements **testable** - each MUST should have a corresponding check
- Use **active voice** - "Component MUST..." not "Must be..."
- **Link to governance** - Reference ADRs and requirements specs for context
- **Be specific** - "MUST use TLS 1.3+" not "MUST be secure"

---

### Phase 3: Plan (Architecture)

**Goal:** Document how we'll implement the requirements.

**Template:** [`.specify/templates/plan-template.md`](../../.specify/templates/plan-template.md)

**Location:** Co-locate with spec
- `stacks/platform/myapp/plan.md`

**Content:**

```markdown
# [Component] Implementation Plan

## Context
<!-- What problem are we solving? Why does this component exist? -->
We need a central authentication service to provide SSO/MFA for all internal services
via forward auth proxy pattern (Caddy + Authentik).

## Approach
<!-- How will we solve it? High-level strategy -->
Deploy Authentik as a Docker Compose stack on NAS, configured for LDAP and OAuth2/OIDC.
Caddy will forward unauthenticated requests to Authentik for validation.

## Tech Stack
<!-- Technologies, tools, libraries -->
- Authentik 2024.2+ (SSO/MFA/forward auth)
- PostgreSQL 16 (Authentik backend)
- Redis 7 (Authentik cache)
- Caddy forward_auth integration
- 1Password for secret materialization

## Architecture
<!-- High-level architecture decisions, component interaction -->
```
[User] → [Caddy :443] → [Authentik :9000] → [Upstream Service]
                  ↓
             [PostgreSQL]
             [Redis]
```
- Caddy handles TLS termination and reverse proxy
- Authentik validates sessions via forward_auth directive
- Sessions stored in PostgreSQL, cached in Redis
- Secrets materialized from 1Password via op-export stack

## Risks
<!-- What could go wrong? Mitigation strategies -->
- **Risk:** PostgreSQL data loss if backup fails
  - **Mitigation:** Daily Restic backups to S3, retention 30d
- **Risk:** Authentik becomes SPOF for all services
  - **Mitigation:** Monitor with Uptime Kuma, fail-open for non-sensitive services

## Dependencies
<!-- What does this depend on? What depends on this? -->
- **Depends on:** Caddy (ingress), op-export (secrets), PostgreSQL
- **Depended on by:** All services requiring authentication
```

**Best Practices:**
- **Be explicit about tradeoffs** - Document why you chose this approach
- **Include diagrams** - ASCII art is fine, shows component relationships
- **List all dependencies** - Both upstream (depends on) and downstream (depended on by)
- **Document risks** - And how you're mitigating them

---

### Phase 4: Tasks (Execution Plan)

**Goal:** Break work into ordered, actionable tasks with acceptance criteria.

**Template:** [`.specify/templates/tasks-template.md`](../../.specify/templates/tasks-template.md)

**Location:** Co-locate with spec and plan
- `stacks/platform/myapp/tasks.md`

**Content:**

```markdown
# [Component] Implementation Tasks

## Prerequisites
<!-- What must exist before starting? -->
- [ ] Caddy stack deployed and healthy
- [ ] PostgreSQL available (can be deployed as part of this work)
- [ ] 1Password vault configured with Authentik secrets

## Tasks

### Task 1: Create PostgreSQL and Redis Services
- **Description:** Deploy PostgreSQL and Redis containers for Authentik backend
- **Files:**
  - `stacks/platform/auth/compose.yaml` (postgres, redis services)
  - `stacks/platform/auth/.env.example` (document required vars)
- **Acceptance criteria:**
  - PostgreSQL listens on :5432, healthcheck passes
  - Redis listens on :6379, healthcheck passes
  - Volumes created for persistent data
- **Dependencies:** None

### Task 2: Configure Authentik Container
- **Description:** Add Authentik container with environment configuration
- **Files:**
  - `stacks/platform/auth/compose.yaml` (authentik service)
  - `stacks/platform/auth/.env.example` (AUTHENTIK_* vars)
- **Acceptance criteria:**
  - Authentik starts successfully
  - Web UI accessible on :9000
  - Initial admin account created
- **Dependencies:** Task 1 (needs PostgreSQL)

### Task 3: Configure Caddy Forward Auth
- **Description:** Update Caddy configuration to use Authentik for forward auth
- **Files:**
  - `stacks/platform/ingress/compose.yaml` (add forward_auth labels)
- **Acceptance criteria:**
  - Unauthenticated requests redirect to Authentik login
  - Authenticated sessions pass through to upstream
  - Session cookies persist across requests
- **Dependencies:** Task 2 (Authentik must be running)

### Task 4: Configure 1Password Secret Injection
- **Description:** Set up secret materialization for Authentik credentials
- **Files:**
  - 1Password vault entries (AUTHENTIK_SECRET_KEY, POSTGRES_PASSWORD)
  - `stacks/scripts/op-export-stack-env.sh` (add auth stack)
- **Acceptance criteria:**
  - Secrets pulled from 1Password on stack start
  - Environment file created with correct permissions (600)
  - Authentik starts with injected secrets
- **Dependencies:** Task 2

## Completion Criteria
<!-- How do we know we're done? -->
- [ ] All tasks completed with acceptance criteria met
- [ ] Authentik stack healthy (docker compose ps shows "healthy")
- [ ] Forward auth works end-to-end (can authenticate to test service)
- [ ] Restic backup includes Authentik volumes
- [ ] Documentation updated (PLATFORM_BOOTSTRAP.md)
- [ ] CI gates pass (no secrets committed, no invariant drift)
```

**Best Practices:**
- **One task per file/component** - Keep tasks focused and atomic
- **Explicit dependencies** - Use "Dependencies: Task N" to show ordering
- **Testable acceptance criteria** - Each criterion should be verifiable
- **Include verification** - Acceptance criteria show how to validate completion

---

### Phase 5: Implement (Execute Tasks)

**Goal:** Execute tasks sequentially, verify acceptance criteria.

**Process:**

1. **Work through tasks in order** - Respect dependencies
2. **Verify acceptance criteria** - Check each criterion before marking task done
3. **Update artifacts if needed** - If requirements/approach changes, update spec/plan/tasks
4. **Run CI gates before PR** - Ensure no governance violations
5. **Document completion** - Update completion criteria checklist

**CI Gates to Run:**

```bash
# Run all gates locally
export PR_TITLE="feat(stacks): add Authentik SSO stack"
export PR_BODY="Adds Authentik for SSO/MFA via forward auth. See stacks/platform/auth/spec.md"
export GITHUB_BASE_REF=main

./scripts/run-all-gates.sh "$PR_TITLE" "$PR_BODY"
```

**Gates validated:**
- `no-invariant-drift.sh` - No hardcoded VLANs, CIDRs, domains in implementation
- `require-adr-on-canonical-changes.sh` - ADR required for canonical changes (N/A for stacks)
- `adr-must-be-linked-from-spec.sh` - ADRs linked from specs (N/A for non-canonical)
- `gitleaks` + `trufflehog` - No secrets committed

---

## Examples

### Example 1: Adding a New Stack (Authentik)

**Directory Structure:**
```
stacks/platform/auth/
├── spec.md              # Requirements (MUST use 1Password, MUST implement OIDC)
├── plan.md              # Architecture (PostgreSQL backend, forward auth integration)
├── tasks.md             # 4 tasks (PostgreSQL, Authentik, Caddy, secrets)
├── compose.yaml         # Implementation
└── .env.example         # Environment template
```

**Workflow:**
1. Constitution review → ✓ No hard-stop violations, aligns with identity-gated access principle
2. Specify → `spec.md` documents MUST requirements (1Password, OIDC, TLS)
3. Plan → `plan.md` documents forward auth architecture, PostgreSQL + Redis dependencies
4. Tasks → `tasks.md` breaks into 4 sequential tasks with acceptance criteria
5. Implement → Execute tasks, verify acceptance criteria, run gates, create PR

### Example 2: Adding Kubernetes Component

**Directory Structure:**
```
kubernetes/components/cert-manager/
├── spec.md              # Requirements (MUST use Let's Encrypt, MUST support DNS-01)
├── plan.md              # Architecture (ClusterIssuer, Cloudflare DNS)
├── kustomization.yaml   # Implementation
├── helmrelease.yaml
└── values.yaml
```

**Workflow:** Same as stacks example, artifacts co-located with kustomize manifests.

### Example 3: Infrastructure Module

**Directory Structure:**
```
infra/networking/vlan-config/
├── spec.md              # Requirements (MUST match invariants, MUST support tagging)
├── plan.md              # Architecture (Terraform module, UniFi provider)
├── tasks.md             # Tasks (provider config, VLAN resources, tagging)
├── main.tf              # Implementation
└── variables.tf
```

**Workflow:** Same workflow, adapted for Terraform.

---

## Integration with CI Gates

Speckit workflow **does NOT bypass** CI gate requirements:

| Gate | Purpose | Still Enforced? |
|------|---------|-----------------|
| `no-invariant-drift.sh` | Prevents hardcoded invariants | ✅ Yes |
| `require-adr-on-canonical-changes.sh` | Requires ADRs for governance | ✅ Yes (canonical only) |
| `adr-must-be-linked-from-spec.sh` | Links ADRs from specs | ✅ Yes (canonical only) |
| `gitleaks` / `trufflehog` | Secret scanning | ✅ Yes |

**Speckit adds planning structure, not governance exemption.**

---

## Speckit vs ADR Summary

| Aspect | Speckit Workflow | ADR Process |
|--------|------------------|-------------|
| **Purpose** | Implementation planning | Architectural decisions |
| **Scope** | Non-canonical work | Canonical changes (required), significant architectural decisions (optional) |
| **Artifacts** | spec.md, plan.md, tasks.md | ADR-NNNN-title.md |
| **Location** | Co-located with implementation | Centralized in `docs/adr/` |
| **Weight** | Lightweight (10-50 lines each) | Comprehensive (100+ lines) |
| **Required?** | Optional (use judgment) | Mandatory for canonical, optional for significant non-canonical |
| **Format** | Requirements/Architecture/Tasks | Context/Decision/Consequences/Alternatives |
| **CI Enforced?** | No | Yes (for canonical changes) |

---

## FAQ

**Q: Do I need both Speckit artifacts AND an ADR for my change?**

A: Rarely. Most changes are either:
- Canonical (governance) → ADR required, no Speckit needed
- Non-canonical (implementation) → Speckit optional, ADR usually not needed

Exception: Major architectural changes to non-canonical areas might warrant both (e.g., "Switch stacks from registry.toml to Komodo" = ADR-0022 for decision, plus spec/plan/tasks for implementation).

**Q: What if I skip Speckit and just implement directly?**

A: That's fine for routine changes! Speckit is optional. Use it when you want structure and traceability, skip it for quick fixes and updates.

**Q: Can I use only some artifacts (e.g., just spec.md, no plan.md)?**

A: Yes. Use what adds value:
- Simple stack → maybe just `spec.md`
- Complex infrastructure → all three (spec, plan, tasks)
- Use judgment based on complexity

**Q: Who reviews Speckit artifacts?**

A: Code owners review during PR process, same as any other change. Artifacts help reviewers understand requirements and approach.

**Q: Do Speckit artifacts need to be linked from requirements specs?**

A: No. Non-canonical specs are co-located with implementation and don't need linking. Only canonical ADRs must be linked from `requirements/*/spec.md`.

---

## References

- **ADR:** [ADR-0024: Speckit Workflow for Non-Canonical Implementation](../adr/ADR-0024-speckit-workflow-non-canonical.md)
- **Related:** [ADR-0005: Agent Governance Procedures](../adr/ADR-0005-agent-governance-procedures.md)
- **Related:** [ADR-0023: Scripts and Stacks Directory Classification](../adr/ADR-0023-scripts-stacks-classification.md)
- **Templates:** [.specify/templates/](../../.specify/templates/)
- **Procedures:** [procedures.md](./procedures.md)
