#!/usr/bin/env bash
set -euo pipefail

# Determine diff base for PR vs push
BASE_REF="${GITHUB_BASE_REF:-}"
if [[ -n "$BASE_REF" ]]; then
  git fetch --no-tags --depth=1 origin "$BASE_REF":"refs/remotes/origin/$BASE_REF" >/dev/null 2>&1 || true
  DIFF_BASE="origin/$BASE_REF"
else
  DIFF_BASE="HEAD~1"
fi

# ADR files changed in this change-set
changed_adrs="$(git diff --name-only "$DIFF_BASE"...HEAD -- 'docs/adr/ADR-*.md' || true)"

if [[ -z "${changed_adrs// }" ]]; then
  echo "✅ No ADR changes detected."
  exit 0
fi

echo "⚠️ ADR changes detected:"
echo "$changed_adrs"
echo

fail=0

# Require a *markdown link* to the specific ADR filename from at least one requirements/**/spec.md.
# We accept typical relative link forms:
#   (../../docs/adr/<file>)
#   (../docs/adr/<file>)
#   (docs/adr/<file>)
#   (./docs/adr/<file>)
# and any variant where docs/adr/<file> appears inside parentheses.
while IFS= read -r adr_file; do
  [[ -n "${adr_file// }" ]] || continue

  adr_base="$(basename "$adr_file")"   # e.g., ADR-0004-title.md
  adr_id="$(echo "$adr_base" | sed -n 's/^\(ADR-[0-9]\{4\}\).*/\1/p')"

  if [[ -z "$adr_id" ]]; then
    echo "❌ Could not parse ADR id from filename: $adr_file"
    fail=1
    continue
  fi

  # Look for a markdown link target containing docs/adr/<ADR filename>
  # i.e., parentheses with docs/adr/ADR-0004-title.md inside.
  # This ensures it's an actual link target, not just a bare mention.
  link_regex="\\([^)]*docs/adr/${adr_base//./\\.}[^)]*\\)"

  if rg -n --pcre2 "$link_regex" requirements/**/spec.md >/dev/null 2>&1; then
    echo "✅ $adr_id is linked from a requirements spec (filename link found)."
  else
    echo "❌ $adr_id is NOT linked from any requirements/**/spec.md (must link filename)."
    echo
    echo "Fix: add a markdown link to the ADR file in the relevant domain spec, e.g.:"
    echo "  See: [$adr_id](../../docs/adr/$adr_base)"
    echo
    echo "Searched for link targets containing:"
    echo "  docs/adr/$adr_base"
    echo
    fail=1
  fi
done <<< "$changed_adrs"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo
echo "✅ All changed ADRs are linked from requirements specs by filename."
