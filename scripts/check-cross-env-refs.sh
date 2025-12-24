#!/usr/bin/env bash
set -euo pipefail

mapfile -t flux_files < <(ls -1 kubernetes/clusters/*/flux/kustomization-*.yaml 2>/dev/null || true)
if [[ ${#flux_files[@]} -eq 0 ]]; then
  echo "⚠️  No Flux kustomization files found"
  exit 0
fi

fail=0

for flux_file in "${flux_files[@]}"; do
  cluster="$(echo "$flux_file" | awk -F'/' '{print $3}')"
  while read -r path; do
    [[ -n "${path}" ]] || continue

    if [[ "${path}" == *".."* ]]; then
      echo "❌ ${flux_file}: path contains traversal: ${path}"
      fail=1
      continue
    fi

    if [[ "${path}" == ./kubernetes/clusters/${cluster}/* ]]; then
      continue
    fi

    if [[ "${path}" == ./kubernetes/components/* ]]; then
      continue
    fi

    if [[ "${path}" == ./kubernetes/policies* ]]; then
      continue
    fi

    echo "❌ ${flux_file}: path may reference another environment: ${path}"
    fail=1
  done < <(rg "^[[:space:]]*path:" "${flux_file}" | sed -E 's/^.*path:[[:space:]]*//')
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "✅ No cross-environment Flux paths detected"
