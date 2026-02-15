#!/usr/bin/env bash
#
# Gate: check-no-agent-grab-bag.sh
#
# Prevents agent instruction files from being created outside of approved locations.
# 
# Agent instructions MUST live in canonical governance documents and approved locations:
# - requirements/workflow/spec.md (Agent Governance Steering section)
# - contracts/agents.md (Agent Operating Rules)
# - .github/copilot-instructions.md (copilot-specific tool guidance)
# - .github/agents/*.agent.md (speckit agent files)
#
# Prohibited agent instruction files:
# - CLAUDE.md - Use canonical governance sources instead
# - .gemini - Use canonical governance sources instead
# - Any other role-specific instruction grab bags

set -euo pipefail

# Approved agent instruction locations
APPROVED_AGENT_FILES=(
    ".github/copilot-instructions.md"
    ".github/agents/*.agent.md"
    "requirements/workflow/spec.md"
    "contracts/agents.md"
)

# Prohibited agent instruction file patterns
PROHIBITED_PATTERNS=(
    "CLAUDE.md"
    "claude.md"
    ".gemini"
    ".gemini.md"
    "GEMINI.md"
)

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "✗ Not in a git repository" >&2
    exit 1
fi

# Get the list of files that would be committed
# (both staged and unstaged changes)
git_files=$(git diff --cached --diff-filter=ACM --name-only 2>/dev/null || true)

# Also check files being added/modified in working tree if not in CI
if [ -z "${CI:-}" ] || [ "${CI:-}" != "true" ]; then
    git_files="$(echo "$git_files"; git diff --diff-filter=ACM --name-only 2>/dev/null || true)"
    git_files=$(echo "$git_files" | sort -u)
fi

found_violations=0

for prohibited_pattern in "${PROHIBITED_PATTERNS[@]}"; do
    # Check if any of the prohibited files are in the changeset
    if echo "$git_files" | grep -q "^${prohibited_pattern}$" || \
       echo "$git_files" | grep -q "${prohibited_pattern}$"; then
        echo "✗ Prohibited agent instruction file detected: $prohibited_pattern" >&2
        echo "  Agent instructions must live in canonical governance sources:" >&2
        echo "  - requirements/workflow/spec.md (Agent Governance Steering section)" >&2
        echo "  - contracts/agents.md (Agent Operating Rules)" >&2
        echo "  - .github/copilot-instructions.md (copilot-specific guidance)" >&2
        echo "  - .github/agents/*.agent.md (speckit agent files)" >&2
        echo "" >&2
        echo "  See: requirements/workflow/spec.md § Agent Instruction Governance" >&2
        found_violations=$((found_violations + 1))
    fi
done

if [ $found_violations -gt 0 ]; then
    echo "" >&2
    echo "✗ GATE FAILED: Found $found_violations prohibited agent instruction file(s)" >&2
    exit 1
fi

echo "✓ GATE PASSED: No prohibited agent instruction files detected"
exit 0
