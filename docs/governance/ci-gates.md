# CI Gates Reference
**Effective:** 2025-12-21

This document describes all CI gates that must pass before merging changes to the main branch.

## Required Status Checks

Per `.github/rulesets/branch-default.json`, these checks are **required** and block merge:

1. `guardrails / no_invariant_drift`
2. `adr-guard / require_adr_for_canonical_changes`
3. `adr-linked / adr-must-be-linked-from-spec`

## Gate 1: no_invariant_drift

**Workflow:** `.github/workflows/guardrails.yml`  
**Job:** `no_invariant_drift`  
**Script:** `./scripts/no-invariant-drift.sh`

### Purpose
Prevents invariant details (network values, domain names, VLAN IDs) from leaking into router/entrypoint files.

### What it validates
Checks that "thin router" files contain only links to canonical sources, not restated invariant values:
- `README.md`
- `agents.md`
- `CLAUDE.md`
- `.github/copilot-instructions.md`
- `.gemini/styleguide.md`

### Prohibited patterns in router files
- Specific network values: `10.0.100.0/24`, `VLAN 100`
- Domain names: `hypyr.space`, `in.hypyr.space`
- Security rules: "Cloudflare Tunnel only", "No port forwards"
- Alternative suffixes: `.lan`, `.local`, `.home`

### Trigger conditions
- `pull_request` (any)
- `push` to `main` or `master`

### How to run locally
```bash
./scripts/no-invariant-drift.sh
```

### Failure modes and fixes
**Failure:** Invariant value found in router file  
**Fix:** Remove the specific value and link to the canonical source instead:
- `constitution/constitution.md`
- `contracts/invariants.md`
- `contracts/hard-stops.md`
- `requirements/**/spec.md`

**Example fix:**
```diff
- Management network uses VLAN 100 (10.0.100.0/24)
+ Management network requirements: see [management spec](requirements/management/spec.md)
```

---

## Gate 2: require_adr_for_canonical_changes

**Workflow:** `.github/workflows/adr-guard.yml`  
**Job:** `require_adr_for_canonical_changes`  
**Script:** `./scripts/require-adr-on-canonical-changes.sh`

### Purpose
Ensures that changes to high-authority files include an ADR reference for traceability and rationale.

### What it validates
If any file in these canonical paths changed:
- `constitution/`
- `contracts/`
- `requirements/`

Then the PR title or body must contain an ADR reference like `ADR-0004`.

**Exemption:** Release PRs created by the release-please bot (`github-actions[bot]`) with titles matching `chore: release` are exempt from this check because individual commits have already passed ADR gates before merging to main. See [ADR-0031: Automated Release Process](../adr/ADR-0031-automated-release-process.md) for rationale.

### Trigger conditions
- `pull_request` (opened, edited, synchronize, reopened)
- `push` to `main` or `master`

### How to run locally
```bash
# Set environment variables as workflow does
export GITHUB_BASE_REF=main
export PR_TITLE="Your PR title"
export PR_BODY="Your PR description"

./scripts/require-adr-on-canonical-changes.sh
```

### Failure modes and fixes
**Failure:** Canonical files changed but no ADR reference found  
**Fix:** Add an ADR reference to the PR title or body:
1. If an ADR already exists for this change, reference it: `ADR-0005`
2. If no ADR exists, create one:
   ```bash
   # Create new ADR with next sequential number
   vim docs/adr/ADR-0005-descriptive-title.md
   
   # Link it from relevant spec
   vim requirements/<domain>/spec.md
   # Add: See: [ADR-0005](../../docs/adr/ADR-0005-descriptive-title.md)
   
   # Reference in PR title or body
   echo "ADR-0005" >> PR description
   ```

---

## Gate 3: adr-must-be-linked-from-spec

**Workflow:** `.github/workflows/adr-linked.yml` *(to be created)*  
**Job:** `adr-must-be-linked-from-spec`  
**Script:** `./scripts/adr-must-be-linked-from-spec.sh`

### Purpose
Ensures that new or modified ADRs are linked from at least one requirements domain spec, maintaining bidirectional traceability.

### What it validates
If any ADR file changed (`docs/adr/ADR-*.md`), the ADR filename must appear in a markdown link within at least one `requirements/**/spec.md` file.

Accepted link formats:
- `(../../docs/adr/ADR-0004-secrets-management.md)`
- `(../docs/adr/ADR-0004-secrets-management.md)`
- `(docs/adr/ADR-0004-secrets-management.md)`
- `(./docs/adr/ADR-0004-secrets-management.md)`

### Trigger conditions
- `pull_request` (any)
- `push` to `main` or `master`

### How to run locally
```bash
# Set environment variables as workflow does
export GITHUB_BASE_REF=main

./scripts/adr-must-be-linked-from-spec.sh
```

### Failure modes and fixes
**Failure:** ADR changed but not linked from any spec  
**Fix:** Add a markdown link in the relevant domain spec:
```bash
# Edit the appropriate domain spec
vim requirements/<domain>/spec.md

# Add link at relevant section
echo "See: [ADR-0005](../../docs/adr/ADR-0005-descriptive-title.md)" >> requirements/<domain>/spec.md
```

**Example:**
If you add `ADR-0005-new-dns-policy.md`, add this to `requirements/dns/spec.md`:
```markdown
## Rationale
See: [ADR-0005](../../docs/adr/ADR-0005-new-dns-policy.md)
```

---

## Gate 4: Secret Scanning

**Workflow:** `.github/workflows/secret-scanning.yml`  
**Jobs:** `gitleaks`, `trufflehog`

### Purpose
Prevents accidental commit of secrets, credentials, and sensitive data.

### What it validates
- Scans all commits for patterns matching known secret formats
- API keys, tokens, passwords, certificates, private keys
- Uses Gitleaks and TruffleHog for redundant detection

### Trigger conditions
- `pull_request` (any)
- `push` to `main` or `master`

### How to run locally

**Using Gitleaks:**
```bash
# Install gitleaks (if not already installed)
# macOS: brew install gitleaks
# Linux: https://github.com/gitleaks/gitleaks/releases

# Scan uncommitted changes
gitleaks detect --source . --verbose

# Scan all history
gitleaks detect --source . --verbose --log-opts="--all"
```

**Using TruffleHog:**
```bash
# Install trufflehog (if not already installed)
# macOS: brew install trufflehog
# Linux: https://github.com/trufflesecurity/trufflehog/releases

# Scan git history
trufflehog git file://. --only-verified
```

### Failure modes and fixes
**Failure:** Secret detected in commit  
**Fix:** Remove the secret immediately:
1. If the secret is in uncommitted changes:
   ```bash
   # Remove the secret from the file
   vim <file-with-secret>
   ```

2. If the secret is already committed:
   ```bash
   # Rewrite history to remove the secret (DANGEROUS)
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch <file-with-secret>" \
     --prune-empty --tag-name-filter cat -- --all
   
   # Force push (only if not yet merged)
   git push origin --force --all
   ```

3. **ALWAYS rotate the exposed secret** - assume it is compromised

4. Add the secret pattern to `.gitignore` if it's a file type that should never be committed

---

## Additional Requirements

### Code Owner Review
Per ruleset, PRs require:
- At least 1 approving review
- Code owner review (see `.github/CODEOWNERS`)
- Last push must be approved
- All review threads must be resolved

### Merge Methods
Only `squash` and `rebase` merge methods are allowed.

### Linear History
Non-fast-forward pushes are blocked. History must remain linear.

---

## Running All Gates Locally

Before pushing, run all gates to ensure CI will pass:

```bash
#!/bin/bash
# Save as: scripts/run-all-gates.sh
set -e

echo "Running all CI gates locally..."
echo

echo "==> Gate 1: no_invariant_drift"
./scripts/no-invariant-drift.sh
echo

echo "==> Gate 2: require_adr_for_canonical_changes"
export GITHUB_BASE_REF=main
export PR_TITLE="${1:-Update}"
export PR_BODY="${2:-}"
./scripts/require-adr-on-canonical-changes.sh
echo

echo "==> Gate 3: adr-must-be-linked-from-spec"
./scripts/adr-must-be-linked-from-spec.sh
echo

echo "==> Gate 4: Secret scanning (gitleaks)"
if command -v gitleaks &> /dev/null; then
  gitleaks detect --source . --verbose
else
  echo "⚠️  gitleaks not installed, skipping"
fi
echo

echo "✅ All gates passed!"
```

Usage:
```bash
chmod +x scripts/run-all-gates.sh
./scripts/run-all-gates.sh "PR Title with ADR-0005" "PR description"
```

---

## Troubleshooting

### Gate appears to pass locally but fails in CI
- Ensure you're testing against the correct base branch
- Check that environment variables match CI context
- Verify `ripgrep` is installed (used by scripts)
- Run with same Git history as CI (full clone, not shallow)

### Multiple gates fail at once
Address them in order:
1. Fix invariant drift first (simplest)
2. Fix ADR references (may require new ADR)
3. Fix ADR linking (add to specs)
4. Fix secrets (most critical)

### Need to bypass a gate temporarily
**Don't.** Gates exist to prevent architectural drift and security issues. If a gate is incorrectly blocking valid work:
1. Open an issue describing the problem
2. Propose a fix to the gate logic
3. Submit a PR to update the gate (requires ADR)
