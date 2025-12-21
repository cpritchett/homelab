# Agent Contract
**Effective:** 2025-12-21

This document defines the strict contract that AI agents must follow when proposing changes to this repository.

## Non-Negotiable Rules

### Agents MUST NEVER:

1. **Weaken or bypass governance gates**
   - Do not modify gate scripts to make them more permissive
   - Do not suggest workarounds to avoid gate failures
   - Do not disable or comment out gate validations
   - Do not propose changes to ruleset requirements without ADR

2. **Skip required ADRs**
   - Canonical changes (`constitution/`, `contracts/`, `requirements/`) ALWAYS require ADR
   - Do not suggest "add ADR later"
   - Do not claim ADR is unnecessary when gate requires it

3. **Restate invariants in router files**
   - Do not put specific values (VLANs, CIDRs, domains) in router files
   - Always link to canonical source instead
   - Router files: `README.md`, `agents.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.gemini/styleguide.md`

4. **Violate constitutional principles**
   - Do not expose services directly to WAN
   - Do not publish `in.hypyr.space` publicly
   - Do not allow non-console access to Management
   - Do not install overlay agents on Management VLAN devices
   - Do not create split-horizon DNS to bypass Cloudflare Access

5. **Commit secrets**
   - Do not propose changes that include credentials, tokens, keys
   - Always run secret scanning before finalizing
   - Do not disable secret scanning tools

6. **Simplify away security boundaries**
   - Do not collapse zones "for simplicity"
   - Do not merge networks "to reduce complexity"
   - Do not remove "unnecessary" access controls without ADR

7. **Make assumptions about routing or network changes**
   - BGP, VLAN, routing policy changes ALWAYS require ADR and human review
   - Do not assume network changes are "small" or "safe"

---

## Agents MUST ALWAYS:

### 1. Run All Gates Before Completing

Before marking work complete, run:
```bash
./scripts/no-invariant-drift.sh
./scripts/require-adr-on-canonical-changes.sh
./scripts/adr-must-be-linked-from-spec.sh
gitleaks detect --source . --verbose  # if available
```

Or use the wrapper:
```bash
./scripts/run-all-gates.sh "PR title" "PR description"
```

**No exceptions.** If gates fail, fix the issues - do not complete without passing.

### 2. Classify Changes Correctly

State the change classification in PR description:
- **Doc-only:** Only affects `docs/`, no governance impact
- **Non-canonical:** Changes implementation (`infra/`, `ops/`) without governance changes
- **Canonical:** Changes `constitution/`, `contracts/`, or `requirements/`
- **Constitutional:** Modifies `constitution/constitution.md`

### 3. Create ADR for Canonical Changes

If change touches `constitution/`, `contracts/`, or `requirements/`:

1. Determine next ADR number: `ls -1 docs/adr/ADR-*.md | tail -1`
2. Create ADR file: `docs/adr/ADR-NNNN-title.md`
3. Link from relevant spec: `requirements/<domain>/spec.md`
4. Include ADR reference in PR title or body: `ADR-NNNN`

Do NOT skip this. CI will block without ADR reference.

### 4. Update Documentation When Changing Governance

If you update `contracts/` or `requirements/`:
- Update related domain specs
- Link new/updated ADRs
- Check for cross-domain impacts
- Update checks.md if validation criteria changed

### 5. Provide Evidence of Compliance

In PR description, include:
```markdown
## Change Classification
[Doc-only | Non-canonical | Canonical | Constitutional]

## ADR Reference
ADR-NNNN (if canonical)

## Gate Results
✅ no_invariant_drift
✅ require_adr_for_canonical_changes  
✅ adr-must-be-linked-from-spec
✅ secret-scanning

## Constitution Compliance
- [ ] Does not violate constitution principles
- [ ] Does not violate invariants
- [ ] Does not trigger hard-stops
- [ ] Relevant specs updated
```

### 6. Link, Don't Restate

In router files, always prefer:
```markdown
✅ See: [management spec](requirements/management/spec.md)
❌ Management uses VLAN 100 (10.0.100.0/24)
```

### 7. Stop and Ask for Hard-Stop Conditions

If change would:
- Expose services to WAN
- Publish internal zone publicly
- Allow non-console Management access
- Install overlay on Management devices
- Override public FQDN internally

**STOP.** Explain the issue and request human guidance. Do not proceed.

---

## Definition of Done

A change is NOT done until:

1. **All gates pass locally:**
   - [ ] `no_invariant_drift` passes
   - [ ] `require_adr_for_canonical_changes` passes
   - [ ] `adr-must-be-linked-from-spec` passes
   - [ ] Secret scanning passes (if tools available)

2. **Required artifacts created:**
   - [ ] ADR created and linked (if canonical)
   - [ ] Specs updated (if governance changed)
   - [ ] Checks.md updated (if validation changed)
   - [ ] PR description complete with classification and evidence

3. **No violations:**
   - [ ] Constitution principles upheld
   - [ ] Invariants maintained
   - [ ] No hard-stop conditions triggered
   - [ ] No secrets committed

4. **Evidence provided:**
   - [ ] Change classification stated
   - [ ] Gate results documented
   - [ ] ADR reference included (if required)
   - [ ] Constitutional compliance confirmed

---

## Change Rubric for Agents

Use this rubric to determine requirements:

### Does change touch these paths?
- `constitution/` → **Canonical** (ADR required, amendment process)
- `contracts/` → **Canonical** (ADR required, specs may need update)
- `requirements/` → **Canonical** (ADR required, must link from spec)
- `docs/` only → **Doc-only** (ADR not required unless documenting decision)
- `infra/`, `ops/` → **Non-canonical** (ADR recommended for architectural changes)

### Does change involve?
- New network segments → **ADR strongly recommended**
- Routing/firewall changes → **ADR required** + human review
- DNS structure changes → **ADR required** + check DNS spec compliance
- New external services → **ADR recommended** + check ingress spec
- Secrets management → **ADR recommended** + secret scanning mandatory
- Security boundaries → **ADR required** + constitutional review

### Quick Decision Tree:
```
Changing constitution/contracts/requirements?
├─ YES → Canonical (ADR required, link from spec, reference in PR)
└─ NO → Non-canonical, but check if:
    ├─ Architectural decision? → ADR strongly recommended
    ├─ Security impact? → ADR strongly recommended  
    ├─ Multi-domain? → ADR recommended
    └─ Bug fix? → ADR not required
```

---

## Common Mistakes to Avoid

### ❌ "Let's add ADR in a follow-up PR"
No. Canonical changes require ADR in the same PR. CI enforces this.

### ❌ "This is a small change, doesn't need ADR"
If it touches `constitution/`, `contracts/`, or `requirements/`, it needs ADR. Size doesn't matter.

### ❌ "I'll just put the VLAN number in README for convenience"
No. This causes invariant drift. Link to the spec instead.

### ❌ "Secret scanning is optional"
No. If you commit secrets, they're compromised. Always scan.

### ❌ "Gates are too strict, let's relax them"
Gates exist for a reason. If a gate incorrectly blocks valid work, fix the gate (with ADR), don't weaken it.

### ❌ "Constitution is outdated, I'll just ignore it"
No. If constitution is wrong, go through amendment process. Don't violate it.

### ❌ "No one will notice if I skip this check"
CI will notice. Reviewers will notice. Don't skip steps.

---

## Agent Checklist Template

Copy this checklist for every change:

```markdown
## Agent Pre-Flight Checklist

### Classification
- [ ] Change classified as: [Doc-only | Non-canonical | Canonical | Constitutional]

### Required Artifacts
- [ ] ADR created (if canonical): ADR-NNNN
- [ ] ADR linked from spec (if canonical)
- [ ] Specs updated (if governance changed)
- [ ] Checks.md updated (if validation changed)

### Gate Validation (run locally)
- [ ] `./scripts/no-invariant-drift.sh` passes
- [ ] `./scripts/require-adr-on-canonical-changes.sh` passes
- [ ] `./scripts/adr-must-be-linked-from-spec.sh` passes
- [ ] Secret scanning passes

### Constitutional Compliance
- [ ] No WAN exposure
- [ ] No public exposure of internal zone
- [ ] No unauthorized Management access
- [ ] No overlay on Management devices
- [ ] No split-horizon DNS bypass
- [ ] All invariants maintained
- [ ] No hard-stops triggered

### Documentation
- [ ] PR title clear and includes ADR (if canonical)
- [ ] PR description complete with evidence
- [ ] Change classification stated
- [ ] Gate results documented
- [ ] Risks noted

### Ready to Submit
- [ ] All above items checked
- [ ] No shortcuts taken
- [ ] Evidence provided
- [ ] Human review requested (if needed)
```

---

## Handling Gate Failures

### If `no_invariant_drift` fails:

1. **Identify** which router file contains invariant
2. **Replace** specific value with link to canonical source
3. **Example:**
   ```diff
   - Management VLAN is 100
   + Management network: see [spec](requirements/management/spec.md)
   ```
4. **Re-run** gate to confirm fix

### If `require_adr_for_canonical_changes` fails:

1. **Check** if canonical files changed: `git diff origin/main -- constitution/ contracts/ requirements/`
2. **Create ADR** following template
3. **Link** from relevant spec
4. **Add** `ADR-NNNN` to PR title or body
5. **Re-run** gate to confirm fix

### If `adr-must-be-linked-from-spec` fails:

1. **Identify** which ADR changed: `git diff origin/main -- docs/adr/`
2. **Find** relevant domain in `requirements/`
3. **Add link** to spec: `See: [ADR-NNNN](../../docs/adr/ADR-NNNN-title.md)`
4. **Re-run** gate to confirm fix

### If secret scanning fails:

1. **Remove secret** from file immediately
2. **Check git history** - is it already committed?
3. **If committed:** Rotate secret immediately (assume compromised)
4. **Add pattern** to `.gitignore` if applicable
5. **Re-run** scanner to confirm clean

---

## Escalation Path

If genuinely blocked by governance:

1. **Explain the situation** clearly in PR or issue
2. **Propose amendment** with rationale
3. **Do NOT bypass** existing rules
4. **Wait for human review**

Valid reasons to escalate:
- Gate incorrectly blocks safe change
- Constitutional requirement prevents critical fix
- Governance is ambiguous or contradictory

Invalid reasons:
- "Too much work to create ADR"
- "Gate is annoying"
- "I think the rule is wrong"

---

## Success Criteria

An agent has succeeded when:

1. ✅ All CI gates pass
2. ✅ No governance violations
3. ✅ Required artifacts created (ADR, spec updates)
4. ✅ Evidence provided in PR
5. ✅ Change classification correct
6. ✅ No shortcuts taken
7. ✅ Constitutional compliance maintained

An agent has FAILED when:

1. ❌ Gates bypassed or weakened
2. ❌ ADR skipped for canonical change
3. ❌ Secrets committed
4. ❌ Constitution violated
5. ❌ Invariants broken
6. ❌ Evidence missing or incomplete
7. ❌ Corners cut "for convenience"

---

## Authority and Precedence

This contract is **subordinate** to:
1. `constitution/constitution.md`
2. `contracts/hard-stops.md`
3. `contracts/invariants.md`
4. `contracts/agents.md`

If this document conflicts with any of the above, the above take precedence.

This contract is **authoritative** over:
- Agent-specific guidance in `agents.md`
- Tool-specific instructions in `.github/copilot-instructions.md`
- Explanatory docs in `docs/`

---

## Updates to This Contract

Changes to this contract:
- Are themselves **canonical changes** (require ADR)
- Must not weaken governance
- Require justification in ADR
- Should improve clarity or enforcement

Do not modify this contract to make it easier to bypass requirements.

---

## Final Reminder

**When in doubt:**
1. Check constitutional principles first
2. Look for existing ADRs on the topic
3. Run gates early and often
4. Ask for human guidance rather than guessing
5. Prefer being too cautious over being too lax

**Remember:**
- Governance exists to prevent mistakes, not to slow you down
- Gates catch real problems, not just theoretical ones
- ADRs provide valuable context for future changes
- Security boundaries are there for a reason
- "Just this once" compounds into architectural drift

**Your role:**
- Follow governance faithfully
- Provide evidence of compliance
- Create required artifacts
- Never skip steps
- Escalate genuine blockers
- Maintain structural safety
