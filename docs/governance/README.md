# Governance Map
**Effective:** 2025-12-21

This document provides a high-level map of governance in this repository: what exists, where it lives, and how it's enforced.

## Governance Structure Overview

```
constitution/
├── constitution.md          [IMMUTABLE PRINCIPLES]
└── amendments/              [Constitutional changes with rationale]

contracts/
├── hard-stops.md            [Human approval required]
├── invariants.md            [Must always be true]
└── agents.md                [Agent operating rules]

requirements/                [DOMAIN SPECS]
├── dns/
│   ├── spec.md             [DNS intent requirements]
│   └── checks.md           [DNS validation checklist]
├── ingress/
│   ├── spec.md             [Cloudflare Tunnel requirements]
│   └── checks.md           [Ingress validation checklist]
├── management/
│   ├── spec.md             [Management network requirements]
│   └── checks.md           [Management validation checklist]
├── overlay/
│   ├── spec.md             [Overlay networking requirements]
│   └── checks.md           [Overlay validation checklist]
└── secrets/
    ├── spec.md             [Secrets management requirements]
    └── checks.md           [Secrets validation checklist]

docs/
├── governance/              [PROCEDURES & GATES]
│   ├── ci-gates.md         [CI gate reference & local commands]
│   ├── procedures.md       [Change workflows & ADR process]
│   └── agent-contract.md   [Strict agent rules]
└── adr/                    [DECISIONS]
    ├── ADR-0001-dns-intent.md
    ├── ADR-0002-tunnel-only-ingress.md
    ├── ADR-0003-management-network.md
    ├── ADR-0004-secrets-management.md
    └── ADR-0005-agent-governance-procedures.md

.github/
├── workflows/               [CI ENFORCEMENT]
│   ├── guardrails.yml      [no_invariant_drift]
│   ├── adr-guard.yml       [require_adr_for_canonical_changes]
│   ├── adr-linked.yml      [adr_must_be_linked_from_spec]
│   └── secret-scanning.yml [gitleaks + trufflehog]
├── rulesets/
│   └── branch-default.json [Required status checks & review rules]
├── CODEOWNERS              [Code ownership requirements]
└── PULL_REQUEST_TEMPLATE.md [PR checklist template]

scripts/
├── no-invariant-drift.sh              [Gate 1 implementation]
├── require-adr-on-canonical-changes.sh [Gate 2 implementation]
├── adr-must-be-linked-from-spec.sh    [Gate 3 implementation]
└── run-all-gates.sh                   [Convenience wrapper]
```

---

## What Governance Exists

### Constitutional Principles
**Location:** `constitution/constitution.md`  
**Type:** Immutable  
**Enforced by:** Human review, hard-stops, invariant checks

Five core principles:
1. Management is Sacred and Boring
2. DNS Encodes Intent
3. External Access is Identity-Gated
4. Routing Does Not Imply Permission
5. Prefer Structural Safety Over Convention

### Hard-Stop Conditions
**Location:** `contracts/hard-stops.md`  
**Type:** Manual approval required  
**Enforced by:** Human review (agents must ask before proceeding)

Five conditions requiring human approval:
1. Exposing services directly to WAN
2. Publishing `in.hypyr.space` publicly
3. Allowing non-console access to Management
4. Installing overlay agents on Management VLAN devices
5. Overriding public FQDN internally to bypass Cloudflare Access

### Invariants
**Location:** `contracts/invariants.md`  
**Type:** Must always be true  
**Enforced by:** CI gates, human review

Three categories:
1. **Network Identity:** Management VLAN 100, CIDR 10.0.100.0/24, zones fixed
2. **Access Rules:** Management isolation, Cloudflare Tunnel only, no overlay on management
3. **DNS Rules:** No additional suffixes, no split-horizon, zone boundaries enforced

### Agent Operating Rules
**Location:** `contracts/agents.md`  
**Type:** Behavioral constraints  
**Enforced by:** Code review, CI gates

Defines:
- What agents MAY do (propose changes, add ADRs, add docs)
- What agents MUST NOT do (violate requirements, simplify boundaries)

### Domain Requirements
**Location:** `requirements/*/spec.md`  
**Type:** Normative constraints per domain  
**Enforced by:** Domain-specific checks, CI gates, human review

Five domains:
1. **DNS** - Zone structure, naming rules, prohibitions
2. **Ingress** - Cloudflare Tunnel requirements, WAN prohibitions
3. **Management** - Network isolation, access rules, VLAN constraints
4. **Overlay** - Trusted endpoints only, management exclusions
5. **Secrets** - Handling, rotation, scanning requirements

### Architecture Decision Records
**Location:** `docs/adr/ADR-*.md`  
**Type:** Historical rationale (append-only)  
**Enforced by:** ADR guard gates, linking requirements

Current ADRs:
- ADR-0001: DNS Intent
- ADR-0002: Tunnel-Only Ingress
- ADR-0003: Management Network
- ADR-0004: Secrets Management
- ADR-0005: Agent Governance Procedures

---

## CI Workflow Enforcement

### Required Status Checks
**Location:** `.github/rulesets/branch-default.json`  
**Enforcement:** Active (blocks merge)

Four required checks:
1. `guardrails / no_invariant_drift`
2. `adr-guard / require_adr_for_canonical_changes`
3. `adr-linked / adr_must_be_linked_from_spec`
4. `secret-scanning / gitleaks` and `secret-scanning / trufflehog`

### Gate 1: no_invariant_drift
**Workflow:** `.github/workflows/guardrails.yml`  
**Script:** `scripts/no-invariant-drift.sh`  
**Purpose:** Prevent invariant details from leaking into router files  
**Trigger:** All PRs, pushes to main  
**Local:** `./scripts/no-invariant-drift.sh`

### Gate 2: require_adr_for_canonical_changes
**Workflow:** `.github/workflows/adr-guard.yml`  
**Script:** `scripts/require-adr-on-canonical-changes.sh`  
**Purpose:** Require ADR reference for constitution/contracts/requirements changes  
**Trigger:** All PRs, pushes to main  
**Local:** `./scripts/require-adr-on-canonical-changes.sh` (with env vars)

### Gate 3: adr_must_be_linked_from_spec
**Workflow:** `.github/workflows/adr-linked.yml`  
**Script:** `scripts/adr-must-be-linked-from-spec.sh`  
**Purpose:** Ensure ADRs are linked from requirement specs  
**Trigger:** All PRs, pushes to main  
**Local:** `./scripts/adr-must-be-linked-from-spec.sh`

### Gate 4: Secret Scanning
**Workflow:** `.github/workflows/secret-scanning.yml`  
**Tools:** Gitleaks, TruffleHog  
**Purpose:** Prevent credential exposure  
**Trigger:** All PRs, pushes to main  
**Local:** `gitleaks detect --source . --verbose`

### Additional Enforcement
**PR Requirements (per ruleset):**
- Code owner approval required
- Minimum 1 approving review
- Last push must be approved
- All review threads must be resolved
- Merge methods: squash or rebase only
- Linear history required (no merge commits)

---

## How Enforcement Works

### Prevention (Pre-PR)
1. **Agent instructions** guide correct behavior
2. **Local gate scripts** catch issues before push
3. **run-all-gates.sh** convenience wrapper

### Validation (PR)
1. **CI workflows** run automatically on PR
2. **Required status checks** block merge if gates fail
3. **Code owner review** provides human validation
4. **PR template** provides checklist

### Enforcement (Merge)
1. **Ruleset** blocks merge without approvals and passing checks
2. **Linear history** requirement prevents complex merges
3. **Squash/rebase only** keeps history clean

### Post-Merge
1. **Gates run on push** to main as final validation
2. **ADRs** provide audit trail of decisions
3. **Append-only ADRs** preserve historical context

---

## Machine-Checkable Governance Map

### Required for All Changes
```yaml
all_changes:
  required_checks:
    - no_invariant_drift
    - secret_scanning
  required_reviews:
    - code_owner: true
    - count: 1
    - last_push_approval: true
  merge_methods:
    - squash
    - rebase
  linear_history: true
```

### Required for Canonical Changes
```yaml
canonical_changes:
  paths:
    - constitution/
    - contracts/
    - requirements/
  required_checks:
    - no_invariant_drift
    - require_adr_for_canonical_changes
    - adr_must_be_linked_from_spec
    - secret_scanning
  required_artifacts:
    - adr:
        location: docs/adr/ADR-NNNN-*.md
        format: sequential_number
        linked_from: requirements/**/spec.md
    - pr_reference: "ADR-NNNN in title or body"
```

### Required for Constitutional Amendments
```yaml
constitutional_amendments:
  paths:
    - constitution/constitution.md
  required_checks:
    - all_canonical_checks
  required_artifacts:
    - adr: required
    - amendment_file: constitution/amendments/YYYY-MM-DD-topic.md
    - downstream_updates: all_affected_contracts_and_requirements
  required_reviews:
    - core_team: true
    - additional_stakeholder_review: recommended
```

### Router File Constraints
```yaml
router_files:
  paths:
    - README.md
    - agents.md
    - CLAUDE.md
    - .github/copilot-instructions.md
    - .gemini/styleguide.md
  prohibited_content:
    - network_values: ["10.0.100.0/24", "VLAN 100"]
    - domain_names: ["hypyr.space", "in.hypyr.space"]
    - security_rules: ["Cloudflare Tunnel only", "No port forwards"]
    - alternative_suffixes: [".lan", ".local", ".home"]
  required_pattern:
    - links_to_canonical_sources_only
```

### Domain-Specific Requirements
```yaml
domains:
  dns:
    spec: requirements/dns/spec.md
    checks: requirements/dns/checks.md
    invariants:
      - public_zone: "hypyr.space"
      - internal_zone: "in.hypyr.space"
      - no_additional_suffixes: true
      - no_split_horizon: true
    
  ingress:
    spec: requirements/ingress/spec.md
    checks: requirements/ingress/checks.md
    invariants:
      - cloudflare_tunnel_only: true
      - no_wan_exposure: true
      - no_port_forwards: true
  
  management:
    spec: requirements/management/spec.md
    checks: requirements/management/checks.md
    invariants:
      - vlan: 100
      - cidr: "10.0.100.0/24"
      - no_internet_egress_default: true
      - console_only_ingress: true
      - no_overlay_agents: true
  
  overlay:
    spec: requirements/overlay/spec.md
    checks: requirements/overlay/checks.md
    invariants:
      - trusted_endpoints_only: true
      - no_management_devices: true
  
  secrets:
    spec: requirements/secrets/spec.md
    checks: requirements/secrets/checks.md
    invariants:
      - no_secrets_in_git: true
      - scanning_required: true
```

---

## Local Validation Commands

### Run All Gates
```bash
./scripts/run-all-gates.sh "PR Title" "PR Body"
```

### Run Individual Gates
```bash
# Check invariant drift
./scripts/no-invariant-drift.sh

# Check ADR requirement (set env vars first)
export GITHUB_BASE_REF=main
export PR_TITLE="Your PR title"
export PR_BODY="Your PR body"
./scripts/require-adr-on-canonical-changes.sh

# Check ADR linking
./scripts/adr-must-be-linked-from-spec.sh

# Scan for secrets
gitleaks detect --source . --verbose
```

### Domain-Specific Checks
```bash
# DNS checks
grep -r "\.lan\|\.local\|\.home" infra/ ops/

# Management VLAN checks
git diff origin/main -- infra/ ops/ | grep -i "vlan.*100\|10\.0\.100"

# WAN exposure checks (manual)
# Review firewall rules and port forwards
```

---

## Quick Reference

### When is ADR Required?
- **Always:** Changes to `constitution/`, `contracts/`, `requirements/`
- **Strongly Recommended:** Network changes, security decisions, architectural changes
- **Recommended:** Multi-domain changes, tool adoption
- **Not Required:** Documentation, bug fixes

### Change Classification
- **Doc-only:** Only `docs/` changes, no governance impact
- **Non-canonical:** Implementation changes (`infra/`, `ops/`), no governance
- **Canonical:** Changes to `constitution/`, `contracts/`, `requirements/` (ADR required)
- **Constitutional:** Changes to `constitution/constitution.md` (ADR + amendment required)

### Agent Definition of Done
- [ ] All gates pass locally
- [ ] ADR created and linked (if canonical)
- [ ] Change classified correctly
- [ ] Evidence provided in PR
- [ ] No constitutional violations

### Files Modified vs Required Actions
| Files Changed | Classification | ADR Required | Gates |
|--------------|----------------|--------------|-------|
| `docs/` only | Doc-only | No | 1, 4 |
| `infra/`, `ops/` | Non-canonical | Recommended* | 1, 4 |
| `requirements/` | Canonical | Yes | 1, 2, 3, 4 |
| `contracts/` | Canonical | Yes | 1, 2, 3, 4 |
| `constitution/` | Constitutional | Yes + Amendment | 1, 2, 3, 4 |

*ADR recommended for architectural changes, required for cross-domain impact

---

## Where to Find More

- **Detailed gate info:** [docs/governance/ci-gates.md](./ci-gates.md)
- **Change procedures:** [docs/governance/procedures.md](./procedures.md)
- **Agent contract:** [docs/governance/agent-contract.md](./agent-contract.md)
- **Constitution:** [constitution/constitution.md](../../constitution/constitution.md)
- **All contracts:** [contracts/](../../contracts/)
- **All requirements:** [requirements/](../../requirements/)
- **All ADRs:** [docs/adr/](../adr/)

---

## Governance Health Metrics

To assess governance health, periodically check:

1. **Gate pass rate:** Are gates catching real issues or too strict?
2. **ADR coverage:** Are canonical changes documented?
3. **Link integrity:** Are ADRs properly linked from specs?
4. **Router file drift:** Are invariants leaking into router files?
5. **Secret exposure:** Are secrets being caught before merge?

Review these metrics quarterly and adjust gates/procedures as needed (with ADR).

---

## Governance Maintenance

### Updating Gates
1. Identify issue with gate behavior
2. Create ADR documenting problem and solution
3. Update gate script in `scripts/`
4. Update workflow if needed
5. Update ci-gates.md documentation
6. Test locally and in CI
7. Reference ADR in PR

### Adding New Requirements
1. Create spec in `requirements/<domain>/spec.md`
2. Create checks in `requirements/<domain>/checks.md`
3. Create ADR documenting requirements
4. Link ADR from spec
5. Update README.md with new domain
6. Consider if new gate needed

### Amending Constitution
1. Create ADR with extensive rationale
2. Create amendment file in `constitution/amendments/`
3. Update `constitution/constitution.md`
4. Update all affected contracts and requirements
5. Link amendment from ADR and ADR from amendment
6. Requires additional review beyond normal code owner

---

**Last Updated:** 2025-12-21  
**Maintained By:** Core team (see `.github/CODEOWNERS`)
