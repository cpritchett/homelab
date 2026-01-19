#!/usr/bin/env bash
# Script: no-invariant-drift.sh
# Purpose: Ensure router files don't contain hardcoded invariant values (must link to canonical sources)
# Usage: Called automatically by run-all-gates.sh and CI, or run standalone
# Dependencies: grep, basic shell utilities
# Maintained by: Governance team
# Last updated: 2025-01-17
# Related: contracts/invariants.md, ADR-0023 (Script organization)
#
# This script validates that "router files" (README.md, agents.md, etc.) contain only
# links to canonical sources rather than restating specific values like VLANs, CIDRs, etc.
# This prevents invariant drift where values get out of sync across files.
set -euo pipefail

# Files that MUST remain "thin routers" (links only, no invariant restatement).
TARGETS=(
  "README.md"
  "agents.md"
  "CLAUDE.md"
  ".github/copilot-instructions.md"
  ".gemini/styleguide.md"
)

# Patterns that indicate invariants leaking into router files.
# (Keep this short + high-signal; tune over time.)
PATTERNS=(
  "10\\.0\\.100\\.0/24"
  "\\bVLAN\\s*100\\b"
  "\\bin\\.hypyr\\.space\\b"
  "\\bhypyr\\.space\\b"
  "Cloudflare Tunnel only"
  "No port forwards"
  "\\.lan\\b"
  "\\.local\\b"
  "\\.home\\b"
)

fail=0

for f in "${TARGETS[@]}"; do
  [[ -f "$f" ]] || continue
  for p in "${PATTERNS[@]}"; do
    if rg -n --pcre2 "$p" "$f" >/dev/null 2>&1; then
      echo "❌ Invariant drift detected in $f"
      rg -n --pcre2 "$p" "$f" || true
      echo
      echo "Fix: remove the invariant text from $f and link to the canonical source instead:"
      echo "  - constitution/constitution.md"
      echo "  - contracts/invariants.md"
      echo "  - contracts/hard-stops.md"
      echo "  - requirements/**/spec.md"
      echo
      fail=1
    fi
  done
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "✅ No invariant drift found in router/tool files."
