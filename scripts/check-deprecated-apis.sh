#!/usr/bin/env bash
set -euo pipefail

# Deprecated or removed API versions (non-exhaustive)
PATTERNS=(
  "apiVersion: extensions/v1beta1"
  "apiVersion: apps/v1beta1"
  "apiVersion: apps/v1beta2"
  "apiVersion: batch/v1beta1"
  "apiVersion: networking.k8s.io/v1beta1"
  "apiVersion: rbac.authorization.k8s.io/v1beta1"
  "apiVersion: policy/v1beta1"
  "apiVersion: apiextensions.k8s.io/v1beta1"
  "apiVersion: admissionregistration.k8s.io/v1beta1"
)

fail=0

for pattern in "${PATTERNS[@]}"; do
  if rg -n "${pattern}" kubernetes bootstrap infra policies ops >/dev/null 2>&1; then
    echo "❌ Deprecated API detected: ${pattern}"
    rg -n "${pattern}" kubernetes bootstrap infra policies ops || true
    fail=1
  fi
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "✅ No deprecated API versions detected"
