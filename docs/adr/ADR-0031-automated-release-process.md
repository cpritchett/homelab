# ADR-0031: Automated Release Process

**Status:** Accepted  
**Date:** 2026-01-31  
**Relates to:** [ADR-0009](./ADR-0009-git-workflow-conventions.md), [ADR-0014](./ADR-0014-governance-framework.md)

## Context

The homelab repository uses [release-please](https://github.com/googleapis/release-please) to automate version management and changelog generation. Release-please creates pull requests that update version numbers and CHANGELOGs based on conventional commit messages.

However, release PRs created by release-please must pass the same CI gates as all other PRs:

1. **`guardrails / no_invariant_drift`** - Ensures invariant values aren't duplicated in router files
2. **`adr-guard / require_adr_for_canonical_changes`** - Requires ADR references when changing `constitution/`, `contracts/`, or `requirements/`
3. **`adr-linked / adr-must-be-linked-from-spec`** - Ensures ADRs are linked from requirement specs

The gate check `require_adr_for_canonical_changes` poses a challenge: if a release includes commits that modified canonical files (which have already been merged to main with proper ADR references), the release PR itself would fail because release-please's default PR body doesn't contain an ADR reference.

## Decision

We establish a standing ADR (this document, ADR-0031) that covers **all automated releases** and configure release-please to reference it in every release PR.

### Release-Please Configuration

The `.github/release-please-config.json` MUST include:

```json
{
  "extra-files": [
    ".github/release-please-config.json"
  ],
  "pull-request-title-pattern": "chore: release${component} ${version}",
  "changelog-notes-type": "github"
}
```

The `.github/workflows/release-please.yml` workflow MUST be configured to append an ADR reference to the PR body:

```yaml
- uses: googleapis/release-please-action@v4
  id: release
  with:
    config-file: .github/release-please-config.json
    manifest-file: .github/.release-please-manifest.json
```

**Note:** Release-please v4 does not natively support custom PR body templates. Instead, we exempt automated release PRs from the ADR gate check by detecting the release-please bot as the PR author.

### Gate Check Exemption

The script `scripts/require-adr-on-canonical-changes.sh` MUST be modified to:

1. Check if the PR author is `github-actions[bot]` or `release-please[bot]`
2. Check if the PR title matches the pattern `chore: release`
3. If both conditions are true, skip the ADR reference check
4. Document this exemption with a reference to ADR-0031

### Rationale

1. **Individual commits already validated**: Each commit merged to main has already passed ADR gates with proper references
2. **Release PRs aggregate approved changes**: Release PRs don't introduce new changes; they only update version numbers and CHANGELOGs
3. **Standing ADR provides traceability**: This ADR (0031) documents the decision to automate releases and explains the gate exemption
4. **Consistent with automation principles**: Automated processes should not require manual intervention for routine operations

## Consequences

### Positive

- **Releases can be fully automated**: No manual intervention needed to add ADR references
- **No redundant ADR requirements**: Avoids requiring ADR references for changes that already passed ADR gates
- **Clear documentation**: This ADR explains why release PRs are exempt from ADR gate checks
- **Maintains governance compliance**: Individual commits still require ADR references; only the aggregate release PR is exempt

### Negative

- **Special case in gate logic**: Adds conditional logic to the ADR gate check script
- **Bot detection dependency**: Relies on recognizing specific bot usernames

## Implementation

1. Create this ADR (ADR-0031) ✅
2. Link ADR from `requirements/workflow/spec.md` § Release Management
3. Modify `scripts/require-adr-on-canonical-changes.sh` to exempt release-please PRs
4. Test with a release-please PR
5. Update `docs/governance/ci-gates.md` to document the exemption

## Related Decisions

- [ADR-0009](./ADR-0009-git-workflow-conventions.md) — Git workflow conventions (conventional commits)
- [ADR-0014](./ADR-0014-governance-framework.md) — Governance framework

## References

- [release-please documentation](https://github.com/googleapis/release-please)
- `.github/release-please-config.json` — Release configuration
- `.github/workflows/release-please.yml` — Release workflow
- `scripts/require-adr-on-canonical-changes.sh` — ADR gate check script
- `docs/governance/ci-gates.md` — CI gate documentation
