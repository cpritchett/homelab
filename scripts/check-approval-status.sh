#!/usr/bin/env bash
set -euo pipefail

# Gate: approval status enforcement
# Fails if any changed governance documents with a Status field have Status: Proposed
# Usage: ./scripts/check-approval-status.sh

BASE_REF=${GITHUB_BASE_REF:-origin/main}

changed_files=$(git --no-pager diff --name-only "$BASE_REF"...HEAD | grep -E '^(docs/adr/ADR-|constitution/amendments/)') || true
changed_files=$(git --no-pager diff --name-only "$BASE_REF"...HEAD | grep -E '\.md$') || true

if [[ -z "$changed_files" ]]; then
  echo "No markdown changes detected; skipping approval status check."
  exit 0
fi

failures=()
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  # Find the first Status line outside of code fences
  status_line=$(awk 'BEGIN{code=0} /^```/{code=!code; next} !code && /^\*\*Status:\*\*/{print; exit 0}' "$f")
  if [[ -n "$status_line" ]]; then
    # If the status line contains Proposed and is not a template list with pipes, fail
    if [[ "$status_line" =~ \*\*Status:\*\*\s*Proposed ]] && [[ ! "$status_line" =~ \| ]]; then
      failures+=("$f")
    fi
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

echo "✅ Approval status check passed (no Proposed statuses in changed governance documents)."
