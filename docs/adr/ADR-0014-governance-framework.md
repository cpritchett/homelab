# ADR-0014: Governance Framework and Policy Enforcement

## Status
Accepted

## Context

The homelab infrastructure has grown to include multiple nodes, storage systems, ingress patterns, and deployment workflows. Without formalized governance:
- Resource constraints (bandwidth, storage capacity) can be violated
- Security best practices may be inconsistently applied
- Configuration drift between nodes becomes difficult to track
- Policy violations are detected reactively rather than proactively

A comprehensive governance framework is needed to:
1. **Define requirements** - Explicit constraints and standards for each domain (compute, storage, DNS, ingress, tooling, workflow)
2. **Enforce policies** - Automated admission control to prevent violations before they reach production
3. **Validate compliance** - CI/CD checks and testing to ensure policies work as intended
4. **Document rationale** - Clear connection between technical constraints and architectural decisions

## Decision

Establish a multi-layered governance framework with the following components:

### 1. Requirements Specifications (`requirements/`)
Domain-specific specifications that define:
- **Purpose and scope** - What the domain covers
- **Constraints** - Hard limits and soft guidelines
- **Standards** - Expected behaviors and configurations
- **Rationale** - Why these constraints exist

**Structure:**
```
requirements/
├── README.md                          # Overview and navigation
├── <domain>/
│   ├── spec.md                        # Domain requirements
│   └── checks.md                      # Validation criteria
```

**Initial domains:**
- `compute/` - Node hardware, Talos configuration
- `storage/` - Longhorn, volume sizes, access modes
- `dns/` - Internal/external DNS patterns
- `ingress/` - Tunnel-only ingress, service constraints
- `tooling/` - Developer tools, CI/CD automation
- `workflow/` - Git conventions, repository structure

### 2. Policy Enforcement (`policies/`)
Kyverno admission policies that:
- Block violations at apply-time (before resources enter cluster)
- Require explicit approval annotations for exceptions
- Align directly with requirements specifications

**Structure:**
```
policies/
├── README.md                          # Policy index and usage
├── <domain>/
│   └── <policy-name>.yaml             # Kyverno ClusterPolicy
```

**Example policies:**
- `storage/deny-oversized-volumes` - Enforce 100Gi max per ADR-0010
- `ingress/deny-loadbalancer-external-ips` - Enforce tunnel-only per ADR-0002
- `secrets/deny-inline-secrets` - Require 1Password references per ADR-0004

### 3. Policy Testing (`test/policies/`)
Test manifests that validate policies work correctly:
- **Valid manifests** - Should be allowed by policies
- **Invalid manifests** - Should be blocked by policies
- Automated in CI/CD to prevent policy regression

### 4. CI/CD Integration
**Workflows:**
- `adr-guard.yml` - Requires ADR reference when canonical files change
- `policy-enforcement.yml` - Validates policies and applies to manifests
- `talos-templates.yml` - Validates Talos node configurations

## Consequences

### Benefits
- **Proactive prevention** - Violations blocked before merge/apply
- **Clear documentation** - Requirements tied to ADRs and policies
- **Testable governance** - Policies have automated test coverage
- **Consistent enforcement** - Policies apply uniformly across all resources
- **Audit trail** - Git history shows all governance changes

### Constraints
- **Policy maintenance overhead** - Policies must be updated as requirements evolve
- **Exception management** - Valid exceptions require approval annotation process
- **Learning curve** - Contributors must understand policy framework
- **Kyverno dependency** - Adds runtime dependency to cluster

### Implementation Notes
- Policies are enforced in **audit mode initially** to identify violations without blocking
- Transition to **enforce mode** after validation period
- Approval annotations require specific format: `policies.kyverno.io/exception: "approved-by-<approver> reason: <justification>"`

## References
- **Related ADRs:**
  - [ADR-0008](ADR-0008-developer-tooling-stack.md) - Kyverno as policy engine
  - [ADR-0009](ADR-0009-git-workflow-conventions.md) - Canonical file protection
  - [ADR-0010](ADR-0010-longhorn-storage.md) - Storage constraints
  - [ADR-0002](ADR-0002-tunnel-only-ingress.md) - Ingress constraints
  - [ADR-0004](ADR-0004-secrets-management.md) - Secrets management

- **Canonical paths:**
  - `constitution/constitution.md` - Overarching principles
  - `contracts/invariants.md` - System invariants
  - `contracts/agents.md` - Agent responsibilities
  - `requirements/` - Domain specifications

- **External references:**
  - [Kyverno documentation](https://kyverno.io)
  - [Policy-as-Code best practices](https://www.cncf.io/blog/2020/08/20/policy-as-code/)
