#!/usr/bin/env bash
set -euo pipefail

# Canonical / high-authority paths
CANONICAL_PATHS=(
  "constitution/"
  "contracts/"
  "requirements/"
)

# We require an ADR reference like ADR-0004 somewhere in PR title/body
ADR_REGEX='ADR-[0-9]{4}'

# Determine base/head for diff
BASE_REF="${GITHUB_BASE_REF:-}"
if [[ -n "$BASE_REF" ]]; then
  # Pull request context
  git fetch --no-tags --depth=1 origin "$BASE_REF":"refs/remotes/origin/$BASE_REF" >/dev/null 2>&1 || true
  DIFF_BASE="origin/$BASE_REF"
else
  # Push context (best-effort): compare to previous commit
  DIFF_BASE="HEAD~1"
fi

# Check if canonical paths changed
changed="$(git diff --name-only "$DIFF_BASE"...HEAD -- "${CANONICAL_PATHS[@]}" || true)"

if [[ -z "${changed// }" ]]; then
  echo "✅ No canonical changes detected."
  exit 0
fi

echo "⚠️ Canonical changes detected:"
echo "$changed"
echo

# Read PR text from env (passed in by workflow); fallback to commit message
PR_TEXT="${PR_TITLE:-} ${PR_BODY:-}"

if [[ -z "${PR_TEXT// }" ]]; then
  PR_TEXT="$(git log -1 --pretty=%B || true)"
fi

# Exemption for automated release PRs (ADR-0031)
# Release-please PRs aggregate previously-approved changes and only update versions/CHANGELOGs
if [[ "${GITHUB_ACTOR:-}" == "github-actions[bot]" ]] && [[ "${PR_TITLE:-}" =~ ^chore:\ release ]]; then
  echo "✅ Release PR detected (created by release-please bot). Exempt from ADR requirement per ADR-0031."
  echo "   Individual commits have already passed ADR gates before merging to main."
  exit 0
fi

if echo "$PR_TEXT" | rg -n --pcre2 "$ADR_REGEX" >/dev/null 2>&1; then
  echo "✅ ADR reference found in PR title/body (or latest commit message)."
  exit 0
fi

echo "❌ Canonical files changed, but no ADR reference found."
echo
echo "Add an ADR reference to the PR title or body, e.g.:"
echo "  ADR-0004"
echo
echo "Or add a new ADR under docs/adr/ and reference it."
exit 1
