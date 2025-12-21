# Governance Procedures
**Effective:** 2025-12-21

This document describes the governance procedures for making changes to this repository.

## Change Classification

All changes fall into one of these categories, each with different requirements:

### 1. Documentation-Only Changes
**Definition:** Changes that only affect explanatory documentation (`docs/`, README updates)

**Requirements:**
- [ ] No constitutional or contract violations
- [ ] Pass secret scanning
- [ ] Code owner review

**No ADR required** unless documenting a new architectural decision.

---

### 2. Non-Canonical Changes
**Definition:** Changes to implementation (`infra/`, `ops/`, scripts) that don't modify governance

**Requirements:**
- [ ] No constitutional or contract violations
- [ ] Pass all CI gates
- [ ] Code owner review
- [ ] No invariant drift in router files

**ADR required only if:**
- Change introduces new architectural patterns
- Change affects multiple domains
- Change has security implications

---

### 3. Canonical Changes
**Definition:** Changes to governance files (`constitution/`, `contracts/`, `requirements/`)

**Requirements:**
- [ ] **ADR reference required** in PR title or body
- [ ] ADR must be linked from relevant `requirements/**/spec.md`
- [ ] Pass all CI gates
- [ ] No invariant drift in router files
- [ ] Code owner review with extra scrutiny
- [ ] Update related domain specs if cross-cutting

**Always requires ADR** - no exceptions.

---

### 4. Constitutional Amendments
**Definition:** Changes to `constitution/constitution.md`

**Requirements:**
- [ ] **ADR required** documenting amendment rationale
- [ ] Amendment file in `constitution/amendments/`
- [ ] Update all affected contracts and requirements
- [ ] Extensive review of downstream impacts
- [ ] Code owner review + additional stakeholder review

**Process:**
1. Create ADR explaining why amendment is needed
2. Create amendment file: `constitution/amendments/YYYY-MM-DD-topic.md`
3. Update constitution
4. Update all affected contracts and requirements
5. Link amendment from ADR and vice versa

---

## When ADRs Are Required

Create an ADR when:

1. **Mandatory (blocks CI):**
   - Changing `constitution/`, `contracts/`, or `requirements/`
   - Creating new ADR files (must link from spec)

2. **Strongly Recommended:**
   - Adding new network segments or VLANs
   - Changing routing or firewall policies
   - Introducing new services or dependencies
   - Changing DNS structure or naming conventions
   - Modifying secrets management approach
   - Making security-impacting decisions

3. **Recommended:**
   - Significant refactoring affecting multiple components
   - Adopting new tools or technologies
   - Reversing previous decisions (document why)

4. **Not Required:**
   - Documentation improvements
   - Bug fixes with no architectural impact
   - Routine updates within established patterns

---

## How to Create an ADR

### Step 1: Determine the next ADR number
```bash
# List existing ADRs
ls -1 docs/adr/ADR-*.md | tail -1

# Next number is current + 1
# Example: if last is ADR-0004, next is ADR-0005
```

### Step 2: Create the ADR file
```bash
# Use format: ADR-NNNN-short-title.md
vim docs/adr/ADR-0005-short-title.md
```

### Step 3: ADR Template
```markdown
# ADR-0005: Short Descriptive Title

**Status:** Accepted  
**Date:** YYYY-MM-DD  
**Author:** Your Name

## Context
What is the situation? What problem are we solving? What constraints exist?

## Decision
What did we decide to do? Be specific and actionable.

## Consequences
What are the positive and negative outcomes of this decision?

### Positive
- Benefit 1
- Benefit 2

### Negative / Tradeoffs
- Drawback 1
- Mitigation for drawback 1

## Alternatives Considered
What other options did we evaluate and why were they rejected?

## References
- Related specs: [spec](../../requirements/domain/spec.md)
- Related ADRs: [ADR-0001](./ADR-0001-example.md)
```

### Step 4: Link from relevant spec
```bash
# Edit the domain spec that this ADR relates to
vim requirements/<domain>/spec.md

# Add link in appropriate section (usually "Rationale" or at end)
# Example:
# See: [ADR-0005](../../docs/adr/ADR-0005-short-title.md)
```

### Step 5: Reference in PR
Include `ADR-0005` in your PR title or description.

---

## PR Format Requirements

### PR Title
- Clear, descriptive summary of change
- Include ADR reference if canonical change: `Add overlay network config (ADR-0006)`

### PR Description
Use the template from `.github/PULL_REQUEST_TEMPLATE.md`:

1. **Summary:** What does this change do?
2. **Specs impact:** Check all that apply
   - Updates `requirements/`
   - Updates `contracts/`
   - Adds/updates ADR
   - Docs-only
3. **Constitution check:** Confirm no violations
4. **Risks:** Note any risks or risk register updates

### Required Checklists
Based on change type, complete relevant sections of PR template.

---

## Required PR Workflow

### Before Creating PR

1. **Classify your change** (doc-only, non-canonical, canonical, constitutional)

2. **Run local validation:**
   ```bash
   # Run all CI gates locally
   ./scripts/run-all-gates.sh "Your PR title with ADR-NNNN" "PR description"
   
   # Or run individually:
   ./scripts/no-invariant-drift.sh
   
   export GITHUB_BASE_REF=main
   export PR_TITLE="Your title"
   export PR_BODY="Your description"
   ./scripts/require-adr-on-canonical-changes.sh
   
   ./scripts/adr-must-be-linked-from-spec.sh
   
   # Secret scan (if tools installed)
   gitleaks detect --source . --verbose
   ```

3. **Create ADR if needed** (canonical changes always need ADR)

4. **Update specs** if contracts or requirements changed

5. **Check invariant drift** - ensure router files contain only links, not values

### During PR Review

1. **Address all review comments** - required by ruleset
2. **Resolve all threads** - blocking requirement
3. **Get code owner approval** - blocking requirement
4. **Ensure CI passes** - all gates must be green
5. **Get final approval after last push** - required by ruleset

### Before Merging

1. **Verify all CI gates pass:**
   - ✅ `guardrails / no_invariant_drift`
   - ✅ `adr-guard / require_adr_for_canonical_changes`
   - ✅ `adr-linked / adr-must-be-linked-from-spec`
   - ✅ `secret-scanning / gitleaks`
   - ✅ `secret-scanning / trufflehog`

2. **Confirm merge method:** Use `squash` or `rebase` only

3. **Ensure linear history:** No merge commits

---

## Code Ownership Requirements

Per `.github/CODEOWNERS`:

- Constitution changes: require core team approval
- Contract changes: require core team approval
- Requirements changes: require domain owner approval
- All PRs: require at least 1 approval

Review `.github/CODEOWNERS` for specific ownership assignments.

---

## Domain-Specific Procedures

### DNS Changes

**When making DNS changes, ensure:**
1. Public services use `*.hypyr.space`
2. Internal services use `*.in.hypyr.space`
3. No additional suffixes (`.lan`, `.local`, `.home`)
4. No split-horizon overrides of public FQDNs

**Validate:**
```bash
# Check DNS spec compliance
grep -r "\.lan\|\.local\|\.home" infra/ ops/ && echo "❌ Prohibited suffix found" || echo "✅ OK"
```

### Ingress Changes

**When making ingress changes, ensure:**
1. All external access via Cloudflare Tunnel only
2. No WAN-exposed ports or listeners
3. No "temporary" port forwards

**Before committing:**
- Review firewall rules for WAN exposure
- Check hard-stops: `contracts/hard-stops.md`

### Management Network Changes

**When making management network changes, ensure:**
1. Management VLAN (100) remains fixed
2. Management CIDR (10.0.100.0/24) remains fixed
3. No overlay agents on management devices
4. Only Mgmt-Consoles can initiate traffic to management

**Validate:**
```bash
# Check for management VLAN changes
git diff origin/main -- infra/ ops/ | grep -i "vlan.*100\|10\.0\.100"
```

### Secrets Management Changes

**When making secrets changes, ensure:**
1. No secrets committed to git
2. Secret scanning passes
3. Rotation procedures documented
4. Access controls updated

**Validate:**
```bash
# Run secret scanners
gitleaks detect --source . --verbose
trufflehog git file://. --only-verified
```

---

## Constitutional Guardrails

### Hard-Stop Conditions

**STOP and ask before:**
1. Exposing services directly to WAN
2. Publishing `in.hypyr.space` publicly
3. Allowing non-console access to Management
4. Installing overlay agents on Management VLAN devices
5. Overriding public FQDNs internally to bypass Cloudflare Access

See: `contracts/hard-stops.md`

### Invariants That Must Always Hold

**Network Identity:**
- Management VLAN: 100 (fixed)
- Management CIDR: 10.0.100.0/24 (fixed)
- Public zone: hypyr.space (Cloudflare-managed)
- Internal zone: in.hypyr.space (local DNS only)

**Access Rules:**
- Management has no Internet egress by default
- Only Mgmt-Consoles initiate to Management
- External ingress is Cloudflare Tunnel only
- No overlay agents on Management VLAN devices

**DNS Rules:**
- No additional internal suffixes
- No split-horizon overrides
- Zone dependency boundaries enforced

See: `contracts/invariants.md`

---

## Validation Commands Summary

### Run All Gates
```bash
./scripts/run-all-gates.sh "PR Title" "PR Body"
```

### Run Individual Gates
```bash
# Check invariant drift
./scripts/no-invariant-drift.sh

# Check ADR requirement for canonical changes
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
# DNS checks (from requirements/dns/checks.md)
grep -r "\.lan\|\.local\|\.home" infra/ ops/
grep -r "hypyr\.space" infra/dns/
grep -r "in\.hypyr\.space" infra/dns/

# Network checks
git diff origin/main -- infra/ | grep -i "vlan\|cidr"

# Secret checks
git diff origin/main -- . | grep -iE "password|secret|key|token|api"
```

---

## Proof of Compliance

For each change, PR description should include:

1. **Change classification:** doc-only | non-canonical | canonical | constitutional
2. **ADR reference:** (if canonical) `ADR-NNNN`
3. **Gate status:**
   ```
   ✅ no_invariant_drift
   ✅ require_adr_for_canonical_changes
   ✅ adr-must-be-linked-from-spec
   ✅ secret-scanning
   ```
4. **Domain checks passed:** (if applicable)
5. **Constitutional compliance confirmed**

---

## Emergency Procedures

### If CI blocks a critical fix:

1. **Assess:** Is the gate correctly blocking unsafe change?
2. **If gate is wrong:** 
   - Create issue documenting gate problem
   - Submit separate PR to fix gate (requires ADR)
   - Request emergency review bypass
3. **If change violates governance:**
   - Refactor change to comply
   - Or document as constitutional amendment

### If secret is committed:

1. **Immediately rotate secret** - assume compromised
2. **Remove from history** if not yet merged
3. **If merged to main:** 
   - Rotate immediately
   - Document incident
   - Update `.gitignore`
   - Consider repo rewrite (extreme)

---

## Questions and Exceptions

### How do I know if I need an ADR?
- Changing `constitution/`, `contracts/`, `requirements/`? **Yes, required.**
- Changing implementation with no governance impact? **Probably not.**
- Making architectural decision? **Yes, strongly recommended.**
- Fixing bug? **No.**
- "Not sure"? **Err on the side of creating one.**

### Can I skip a gate if I'm certain it's not relevant?
No. Gates exist to prevent mistakes. If a gate incorrectly blocks valid work, fix the gate (with ADR) rather than bypassing it.

### What if I disagree with governance?
1. Open issue to discuss
2. Propose constitutional amendment or contract change
3. Follow amendment process (requires ADR)
4. Do not bypass or work around existing rules

### What if I need to make a change urgently?
Urgency does not override governance. If existing governance prevents a necessary emergency change, that indicates governance is too restrictive and should be amended (after the emergency is resolved).

---

## See Also

- CI Gates Details: [ci-gates.md](./ci-gates.md)
- Agent Contract: [agent-contract.md](./agent-contract.md)
- Constitution: [constitution/constitution.md](../../constitution/constitution.md)
- Contracts: [contracts/](../../contracts/)
- Requirements: [requirements/](../../requirements/)
