#!/usr/bin/env bash
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
