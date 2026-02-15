#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "❌ gitleaks is not installed. Install via: mise install" >&2
  exit 1
fi

FIXTURE_DIR=test/security/fixtures

# Expect failures on synthetic secret fixtures (using built-in rules + custom)
if [[ -d "$FIXTURE_DIR" ]]; then
  if gitleaks detect --no-git --source "$FIXTURE_DIR" --redact --config .gitleaks.fixtures.toml >/tmp/gitleaks-fixtures.log 2>&1; then
    echo "❌ Expected gitleaks to flag synthetic fixtures, but it passed."
    cat /tmp/gitleaks-fixtures.log
    exit 1
  fi
  echo "✅ Gitleaks correctly flags synthetic secret fixtures."
else
  echo "⚠️  Fixture directory $FIXTURE_DIR not found, skipping synthetic secret test."
fi

# Optional: ensure a safe sample passes
SAFE_DIR=test/security/safe
if [[ -d "$SAFE_DIR" ]]; then
  if ! gitleaks detect --no-git --source "$SAFE_DIR" --redact --config .gitleaks.toml >/tmp/gitleaks-safe.log 2>&1; then
    echo "❌ Expected safe fixtures to pass, but gitleaks reported findings."
    cat /tmp/gitleaks-safe.log
    exit 1
  fi
  echo "✅ Safe fixtures pass."
fi
