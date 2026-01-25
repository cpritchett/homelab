#!/bin/bash
# enforce-markdown-allowlist.sh
# Validates that all .md files in the repository conform to ADR-0025 allowlist
# See: docs/adr/ADR-0025-strict-markdown-governance.md

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VIOLATIONS=0

echo "🔍 Checking markdown file allowlist (ADR-0025)..."
echo ""

# Find all .md files in the repository (excluding .git and spec artifacts)
MARKDOWN_FILES=$(find . -name "*.md" -type f \
  ! -path "./.git/*" \
  ! -path "./node_modules/*" \
  ! -path "./.specify/*" \
  | sort)

# Allowlist patterns (regex)
declare -a ALLOWLIST=(
  # Root level
  "^\.\/README\.md$"
  "^\.\/CONTRIBUTING\.md$"
  "^\.\/CLAUDE\.md$"
  "^\.\/agents\.md$"
  "^\.\/\.github\/copilot-instructions\.md$"
  "^\.\/\.github\/PULL_REQUEST_TEMPLATE\.md$"
  
  # .github/ - speckit agents and prompts
  "^\.\/\.github\/agents\/speckit\.[^/]*\.agent\.md$"
  "^\.\/\.github\/agents\/[^/]*\.agent\.md$"
  "^\.\/\.github\/prompts\/speckit\.[^/]*\.prompt\.md$"
  "^\.\/\.github\/prompts\/[^/]*\.prompt\.md$"
  
  # .gemini/ - style guides and references
  "^\.\/\.gemini\/[^/]*\.md$"
  
  # docs/adr/ - ADR-NNNN-*.md only
  "^\.\/docs\/adr\/ADR-[0-9]\{4\}-[^/]*\.md$"
  "^\.\/docs\/adr\/README\.md$"
  
  # docs/* - general documentation
  "^\.\/docs\/[^/]*\.md$"
  
  # docs/governance, docs/operations, etc.
  "^\.\/docs\/[^/]*\/[^/]*\.md$"
  
  # ops/
  "^\.\/ops\/README\.md$"
  "^\.\/ops\/CHANGELOG\.md$"
  "^\.\/ops\/runbooks\/[^/]*\.md$"
  
  # requirements/* - canonical specs, checks, and domain docs
  "^\.\/requirements\/[^/]*\/spec\.md$"
  "^\.\/requirements\/[^/]*\/checks\.md$"
  "^\.\/requirements\/[^/]*\/[^/]*\.md$"
  "^\.\/requirements\/README\.md$"
  
  # specs/NNN-*/ - speckit-approved files only
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/spec\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/plan\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/research\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/data-model\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/quickstart\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/contracts\/[^/]*\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/checklists\/[^/]*\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/tasks\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/[^/]*\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/[^/]*/[^/]*\.md$"
  "^\.\/specs\/[0-9]\{3\}-[^/]*\/.*\.md$"
  "^\.\/specs\/.*\.md$"
  
  # talos/
  "^\.\/talos\/README\.md$"
  "^\.\/talos\/spec\.md$"
  "^\.\/talos\/checks\.md$"
  
  # bootstrap/
  "^\.\/bootstrap\/README\.md$"
  "^\.\/bootstrap\/spec\.md$"
  "^\.\/bootstrap\/checks\.md$"
  
  # kubernetes/ - README only
  "^\.\/kubernetes\/README\.md$"
  
  # constitution/ - canonical files
  "^\.\/constitution\/constitution\.md$"
  "^\.\/constitution\/amendments\/[^/]*\.md$"
  
  # contracts/ - canonical files
  "^\.\/contracts\/agents\.md$"
  "^\.\/contracts\/hard-stops\.md$"
  "^\.\/contracts\/invariants\.md$"
  
  # infra/ - infrastructure documentation
  "^\.\/infra\/README\.md$"
  "^\.\/infra\/[^/]*\/README\.md$"
  
  # kubernetes/ - complete tree
  "^\.\/kubernetes\/[^/]*\.md$"
  "^\.\/kubernetes\/[^/]*/[^/]*\.md$"
  "^\.\/kubernetes\/[^/]*/[^/]*/[^/]*\.md$"
  "^\.\/kubernetes\/[^/]*/[^/]*/[^/]*/[^/]*\.md$"
  "^\.\/kubernetes\/[^/]*/[^/]*/[^/]*/[^/]*/[^/]*\.md$"
  "^\.\/kubernetes\/[^/]*/[^/]*/[^/]*/[^/]*/[^/]*/[^/]*\.md$"
  "^\.\/kubernetes\/[^/]*/[^/]*/[^/]*/[^/]*/[^/]*/[^/]*/[^/]*\.md$"
  
  # bootstrap/ - values and nested
  "^\.\/bootstrap\/values\/[^/]*\.md$"
  
  # stacks/ - docs and platform docs (brownfield)
  "^\.\/stacks\/docs\/[^/]*\.md$"
  "^\.\/stacks\/platform\/[^/]*\/README\.md$"
  "^\.\/stacks\/platform\/[^/]*/[^/]*\/README\.md$"
  
  # test/ - policy test docs
  "^\.\/test\/[^/]*\/README\.md$"

  # policies/ - policy docs
  "^\.\/policies\/[^/]*\.md$"
  "^\.\/policies\/[^/]*/[^/]*\.md$"
)

# Function to check if file matches allowlist
matches_allowlist() {
  local file="$1"
  for pattern in "${ALLOWLIST[@]}"; do
    if [[ "$file" =~ $pattern ]]; then
      return 0
    fi
  done
  return 1
}

# Check each markdown file
for md_file in $MARKDOWN_FILES; do
  if ! matches_allowlist "$md_file"; then
    echo -e "${RED}✗ VIOLATION${NC}: $md_file"
    echo "  Reason: Not on markdown allowlist (ADR-0025)"
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    echo -e "${GREEN}✓${NC} $md_file"
  fi
done

echo ""

if [ $VIOLATIONS -eq 0 ]; then
  echo -e "${GREEN}✅ All markdown files conform to allowlist${NC}"
  exit 0
else
  echo -e "${RED}❌ Found $VIOLATIONS markdown file violation(s)${NC}"
  echo ""
  echo "Fix: Remove or relocate disallowed markdown files."
  echo "Reference: docs/adr/ADR-0025-strict-markdown-governance.md"
  echo ""
  echo "Permitted locations:"
  echo "  - Root: README.md, CONTRIBUTING.md, CLAUDE.md, agents.md"
  echo "  - docs/adr/ADR-NNNN-*.md (append-only)"
  echo "  - docs/*, docs/governance/*, docs/operations/*"
  echo "  - ops/CHANGELOG.md, ops/README.md, ops/runbooks/*"
  echo "  - requirements/*/spec.md, requirements/*/checks.md"
  echo "  - specs/NNN-*/{spec,plan,research,data-model,quickstart}.md"
  echo "  - specs/NNN-*/{contracts,checklists,tasks}/"
  echo "  - talos/, bootstrap/ (spec.md, checks.md, README.md only)"
  echo "  - infra/README.md, infra/*/README.md"
  exit 1
fi
