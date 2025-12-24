#!/usr/bin/env bash
set -euo pipefail

if ! command -v ytt >/dev/null 2>&1; then
  echo "⚠️  ytt not installed; skipping Talos render check"
  exit 0
fi

if [[ ! -x "./talos/render.sh" ]]; then
  echo "❌ talos/render.sh not found or not executable"
  exit 1
fi

./talos/render.sh --validate

echo "✅ Talos ytt render check passed"
