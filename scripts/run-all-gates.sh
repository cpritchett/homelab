#!/usr/bin/env bash
# NOTE: Ensure this script is committed as executable:
#   git update-index --chmod=+x scripts/run-all-gates.sh
set -e

echo "Running all CI gates locally..."
echo

echo "==> Gate 1: no_invariant_drift"
./scripts/no-invariant-drift.sh
echo

echo "==> Gate 2: require_adr_for_canonical_changes"
export GITHUB_BASE_REF=main
export PR_TITLE="${1:-Update}"
export PR_BODY="${2:-}"
./scripts/require-adr-on-canonical-changes.sh
echo

echo "==> Gate 3: adr-must-be-linked-from-spec"
./scripts/adr-must-be-linked-from-spec.sh
echo

echo "==> Gate 4: Secret scanning (gitleaks)"
if command -v gitleaks &> /dev/null; then
  gitleaks detect --source . --verbose
else
  if [ -n "${CI:-}" ]; then
    echo "ERROR: gitleaks is required in CI but is not installed. Please install gitleaks in the CI environment." >&2
    exit 1
  else
    echo "⚠️  gitleaks not installed, skipping"
  fi
fi
echo

echo "✅ All gates passed!"
