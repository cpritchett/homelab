#!/usr/bin/env bash
set -euo pipefail

ALLOWLIST=(
  "bootstrap/resources.yaml"
)

is_allowlisted() {
  local file="$1"
  for allowed in "${ALLOWLIST[@]}"; do
    if [[ "$file" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

mapfile -t secret_files < <(rg -l "^kind: Secret$" -S kubernetes bootstrap infra ops 2>/dev/null || true)

if [[ ${#secret_files[@]} -eq 0 ]]; then
  echo "✅ No Secret manifests found"
  exit 0
fi

fail=0

for f in "${secret_files[@]}"; do
  if rg -n "^sops:" "$f" >/dev/null 2>&1; then
    echo "✓ ${f}: Secret is SOPS-encrypted"
    continue
  fi

  if is_allowlisted "$f"; then
    echo "⚠️  ${f}: Secret manifest allowlisted (bootstrap placeholder)"
    continue
  fi

  echo "❌ ${f}: plaintext Secret manifest detected"
  fail=1
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "✅ No plaintext Secret manifests detected"
