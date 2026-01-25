#!/usr/bin/env bash
set -euo pipefail

# Gate: approval status enforcement
# Fails if any changed ADRs or constitutional amendments have Status: Proposed
# Usage: ./scripts/check-approval-status.sh

BASE_REF=${GITHUB_BASE_REF:-origin/main}

changed_files=$(git --no-pager diff --name-only "$BASE_REF"...HEAD | grep -E '^(docs/adr/ADR-|constitution/amendments/)') || true

if [[ -z "$changed_files" ]]; then
  echo "No ADR or amendment changes detected; skipping approval status check."
  exit 0
fi

failures=()
while IFS= read -r f; do
  if [[ ! -f "$f" ]]; then
    continue
  fi
  if grep -qE '^\*\*Status:\*\*\s*Proposed' "$f"; then
    failures+=("$f")
  fi
done < <(printf "%s\n" $changed_files)

if (( ${#failures[@]} > 0 )); then
  echo "❌ Proposed-status documents detected in changed files (cannot be committed):"
  for f in "${failures[@]}"; do
    echo "  - $f"
  done
  echo "\nResolution: Change '**Status:** Proposed' to '**Status:** Accepted' after explicit human approval."
  exit 1
fi

echo "✅ Approval status check passed (no Proposed statuses in changed ADRs/amendments)."
