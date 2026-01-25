#!/usr/bin/env bash
# Fails if any spec.md is outside allowed locations.
# Canonical: requirements/<domain>/spec.md
# Non-canonical: specs/NNN-<slug>/spec.md
# Authority: ADR-0026

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "🔍 Checking spec placement (ADR-0026)..."

violations=0

readarray -t spec_files < <(find . -name "spec.md" -type f \
  ! -path "./.git/*" \
  ! -path "./.specify/*" \
  ! -path "./node_modules/*" \
  | sort)

allowlist=(
  "^\./requirements/[^/]+/spec\\.md$"
  "^\./specs/[0-9]{3}-[^/]+/spec\\.md$"
)

matches_allowlist() {
  local file="$1"
  for pattern in "${allowlist[@]}"; do
    if [[ "$file" =~ $pattern ]]; then
      return 0
    fi
  done
  return 1
}

for file in "${spec_files[@]}"; do
  if matches_allowlist "$file"; then
    echo -e "${GREEN}✓${NC} $file"
  else
    echo -e "${RED}✗ VIOLATION${NC}: $file"
    echo "  Reason: spec.md must live in requirements/<domain>/ or specs/NNN-<slug>/ per ADR-0026"
    violations=$((violations + 1))
  fi
done

echo
if [[ $violations -gt 0 ]]; then
  echo -e "${RED}❌ Found $violations spec placement violation(s)${NC}"
  exit 1
fi

echo -e "${GREEN}✅ All spec.md files comply with ADR-0026${NC}"
