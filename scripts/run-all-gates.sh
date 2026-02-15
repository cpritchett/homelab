#!/usr/bin/env bash
# NOTE: Ensure this script is committed as executable:
#   git update-index --chmod=+x scripts/run-all-gates.sh
set -e

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

BASE_REF="${GITHUB_BASE_REF:-main}"
BASE_POINT=""
if git show-ref --verify --quiet "refs/remotes/origin/${BASE_REF}"; then
  BASE_POINT=$(git merge-base HEAD "origin/${BASE_REF}" || git rev-parse HEAD^ || git rev-parse HEAD)
else
  BASE_POINT=$(git rev-parse HEAD^ 2>/dev/null || git rev-parse HEAD)
fi

changed_files() {
  git diff --name-only "${BASE_POINT}..HEAD" 2>/dev/null || true
}

has_changes() {
  local pattern="$1"
  if [[ -z "${BASE_POINT}" ]]; then
    return 0
  fi
  changed_files | rg -q "${pattern}"
}

echo "==> Gate 1: Markdown allowlist (ADR-0025)"
./scripts/enforce-markdown-allowlist.sh
echo

echo "==> Gate 2: Spec placement (ADR-0026)"
./scripts/check-spec-placement.sh
echo

echo "==> Gate 3: Agent instruction governance (no grab bags)"
./scripts/check-no-agent-grab-bag.sh
echo

echo "==> Gate 4: no_invariant_drift"
./scripts/no-invariant-drift.sh
echo

echo "==> Gate 5: require_adr_for_canonical_changes"
export GITHUB_BASE_REF=main
export PR_TITLE="${1:-Update}"
export PR_BODY="${2:-}"
./scripts/require-adr-on-canonical-changes.sh
echo

echo "==> Gate 6: approval_status_enforced"
bash ./scripts/check-approval-status.sh
echo

echo "==> Gate 7: adr-must-be-linked-from-spec"
./scripts/adr-must-be-linked-from-spec.sh
echo

echo "==> Gate 8: Secret scanning (gitleaks)"
if command -v gitleaks &> /dev/null; then
  GITLEAKS_CONFIG=".gitleaks.toml"
  GITLEAKS_ALLOWLIST=".gitleaks.allowlist"
  if [[ -f "${GITLEAKS_CONFIG}" ]]; then
    if [[ -f "${GITLEAKS_ALLOWLIST}" ]]; then
      gitleaks detect --source . --verbose --config "${GITLEAKS_CONFIG}" --gitleaks-ignore-path "${GITLEAKS_ALLOWLIST}"
    else
      gitleaks detect --source . --verbose --config "${GITLEAKS_CONFIG}"
    fi
  else
    gitleaks detect --source . --verbose
  fi

  # Mirror CI's diff scan when we can determine a base ref.
  if [[ -n "${BASE_POINT}" ]]; then
    if [[ -f "${GITLEAKS_CONFIG}" ]]; then
      if [[ -f "${GITLEAKS_ALLOWLIST}" ]]; then
        gitleaks detect --redact --config "${GITLEAKS_CONFIG}" --gitleaks-ignore-path "${GITLEAKS_ALLOWLIST}" --log-opts="${BASE_POINT}..HEAD"
      else
        gitleaks detect --redact --config "${GITLEAKS_CONFIG}" --log-opts="${BASE_POINT}..HEAD"
      fi
    else
      gitleaks detect --redact --log-opts="${BASE_POINT}..HEAD"
    fi
  else
    echo "ℹ️  Skipping gitleaks diff scan (no base point available)."
  fi

  # Mirror CI's synthetic fixture test.
  ./scripts/security-test.sh
else
  if [ -n "${CI:-}" ]; then
    echo "ERROR: gitleaks is required in CI but is not installed. Please install gitleaks in the CI environment." >&2
    exit 1
  else
    echo "⚠️  gitleaks not installed, skipping"
  fi
fi
echo

echo "==> Gate 8: Policy enforcement (conditional)"
if has_changes '^(infra/|policies/).*\.(ya?ml)$'; then
  if command -v kyverno >/dev/null 2>&1 && command -v yq >/dev/null 2>&1; then
    echo "Validating policy YAML syntax..."
    for policy in policies/**/*.yaml; do
      echo "Checking $policy..."
      yq eval '.' "$policy" >/dev/null
    done
    echo "✓ All policies have valid YAML syntax"

    find infra -type f \( -name "*.yaml" -o -name "*.yml" \) \
      ! -name "kustomization.yaml" \
      ! -name "README.md" \
      > /tmp/policy-manifest-files.txt || true

    if [[ -s /tmp/policy-manifest-files.txt ]]; then
      failed=0
      while IFS= read -r manifest; do
        echo "=== Checking $manifest ==="
        for policy in policies/storage/*.yaml; do
          if kyverno apply "$policy" --resource "$manifest" > /tmp/policy-result.txt 2>&1; then
            echo "✓ $policy: PASS"
          else
            echo "✗ $policy: FAIL"
            cat /tmp/policy-result.txt
            failed=1
          fi
        done
        for policy in policies/ingress/*.yaml; do
          if kyverno apply "$policy" --resource "$manifest" > /tmp/policy-result.txt 2>&1; then
            echo "✓ $policy: PASS"
          else
            echo "✗ $policy: FAIL"
            cat /tmp/policy-result.txt
            failed=1
          fi
        done
        for policy in policies/secrets/*.yaml; do
          if kyverno apply "$policy" --resource "$manifest" > /tmp/policy-result.txt 2>&1; then
            echo "✓ $policy: PASS"
          else
            echo "✗ $policy: FAIL"
            cat /tmp/policy-result.txt
            failed=1
          fi
        done
        echo
      done < /tmp/policy-manifest-files.txt

      if [[ $failed -eq 1 ]]; then
        exit 1
      fi
    else
      echo "No manifest files found in infra/ (expected during bootstrap)."
    fi
  else
    if [ -n "${CI:-}" ]; then
      echo "ERROR: kyverno and yq are required in CI for policy enforcement." >&2
      exit 1
    else
      echo "⚠️  kyverno or yq not installed, skipping policy enforcement."
    fi
  fi
else
  echo "No infra/policies YAML changes; skipping."
fi
echo

echo "✅ All gates passed!"
