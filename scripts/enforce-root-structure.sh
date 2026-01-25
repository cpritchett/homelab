#!/usr/bin/env bash
set -euo pipefail

# Wrapper script for Conftest-based repository structure validation
# Policy is defined in policies/repository/deny-unauthorized-root-files.rego

# Ensure mise is activated (conftest installed via .mise.toml)
if ! command -v conftest &> /dev/null; then
  echo "❌ Conftest not found. Ensure mise is activated:"
  echo "   eval \"\$(mise activate bash)\"  # or zsh/fish"
  echo "   mise install"
  echo
  echo "Conftest should be installed via mise (.mise.toml), not brew/curl."
  exit 1
fi

echo "Validating repository root structure..."

# Create temporary JSON input for conftest
temp_input=$(mktemp "${TMPDIR:-/tmp}/root-structure.XXXXXX.json")
trap 'rm -f "$temp_input"' EXIT

# Build JSON input with all root-level files and directories
{
  echo "["
  
  # Add root-level files
  first=true
  for file in *; do
    [[ -f "$file" ]] || continue
    if [[ "$first" == true ]]; then
      first=false
    else
      echo ","
    fi
    echo -n "  {\"filename\": \"$file\"}"
  done
  
  # Add root-level directories
  for dir in */; do
    dir="${dir%/}"
    if [[ "$first" == true ]]; then
      first=false
    else
      echo ","
    fi
    echo -n "  {\"dirname\": \"$dir\"}"
  done
  
  echo
  echo "]"
} > "$temp_input"

# Run conftest with the repository structure policy
if conftest test "$temp_input" \
  --policy policies/repository/ \
  --namespace main \
  --output stdout; then
  echo "✅ Repository root structure is compliant."
  exit 0
else
  echo
  echo "Fix: Move or remove unauthorized files/directories."
  echo "See: requirements/workflow/repository-structure.md"
  exit 1
fi
