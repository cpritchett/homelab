# Runbook: Break-glass (Intentional Invariant Violation)

This runbook is used when you intentionally violate an invariant to restore service, regain access, or perform urgent maintenance.

**Default stance:** avoid break-glass. If used, it must be time-boxed and reversed.

---

## When break-glass is allowed
Use break-glass only for:
- restoring access (operator lockout)
- urgent recovery (service outage impacting your ability to manage the lab)
- critical maintenance (e.g., firmware updates that cannot be staged safely)

## Preconditions
- You have console-level access to the environment you’re modifying
- You understand which invariant you’re violating and why

## Step 0: Declare the break-glass
Before changing anything, write down:
- **Which invariant is being violated** (link to `contracts/invariants.md`)
- **Why** (what fails if you don’t)
- **Scope** (which device(s), VLAN(s), service(s))
- **Timebox** (explicit end time)
- **Rollback plan** (how you will restore invariants)

Suggested format (paste into PR description or notes):
- Invariant violated:
- Reason:
- Scope:
- Timebox:
- Rollback:

## Step 1: Implement the minimal exception
Rules:
- smallest change
- narrowest scope
- shortest duration
- prefer allowlist over broad allow

Examples (conceptual):
- temporary egress allow for a single management endpoint to fetch firmware
- temporary access rule for a single Mgmt-Console to regain management reachability

## Step 2: Verify the immediate objective
- Confirm the recovery goal is met (access restored / update applied / outage resolved)

## Step 3: Restore invariants
- Remove the exception
- Re-verify:
  - management has no default internet egress
  - only Mgmt-Consoles can initiate into management
  - no WAN exposure exists
  - overlay is not installed on management endpoints

## Step 4: Record the decision (required)
Within the same PR (or immediately after), add:
- an ADR documenting the exception pattern **if it’s likely to recur**, OR
- a short entry in `ops/CHANGELOG.md` describing what happened

If the invariant itself needs modification long-term:
- create an amendment under `constitution/amendments/`
- update `contracts/invariants.md`
- reference an ADR

## Post-incident checklist
- [ ] Exception removed
- [ ] Invariant state restored
- [ ] ADR or changelog entry added
- [ ] Any new tooling/runbook improvements captured
