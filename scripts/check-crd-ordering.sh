#!/usr/bin/env bash
set -euo pipefail

# Heuristic checks for ordering based on known Flux entrypoints.
# This is best-effort and should be expanded once CRD ownership is codified.

fail=0

apps_depends_on="$(rg -n "^\s*dependsOn:" -C 5 kubernetes/clusters/*/flux/kustomization-apps.yaml 2>/dev/null || true)"
if ! rg -q -- "- name: platform" kubernetes/clusters/*/flux/kustomization-apps.yaml 2>/dev/null; then
  echo "❌ apps kustomization should dependOn platform"
  fail=1
fi

if ! rg -q -- "- name: kyverno" kubernetes/clusters/*/flux/kustomization-policies.yaml 2>/dev/null; then
  echo "❌ policies kustomization should dependOn kyverno"
  fail=1
fi

if ! rg -q -- "- name: policies" kubernetes/clusters/*/flux/kustomization-platform.yaml 2>/dev/null; then
  echo "❌ platform kustomization should dependOn policies"
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "✅ CRD/CR ordering heuristic checks passed"
