#!/usr/bin/env bash
set -euo pipefail

SKIP_REMOTE="${SKIP_REMOTE:-1}"

if ! command -v kustomize >/dev/null 2>&1; then
  echo "⚠️  kustomize not installed; skipping kustomize build checks"
  exit 0
fi

mapfile -t flux_files < <(ls -1 kubernetes/clusters/*/flux/kustomization-*.yaml 2>/dev/null || true)
if [[ ${#flux_files[@]} -eq 0 ]]; then
  echo "⚠️  No Flux kustomization files found under kubernetes/clusters/*/flux"
  exit 0
fi

fail=0

for flux_file in "${flux_files[@]}"; do
  while read -r path; do
    [[ -n "${path}" ]] || continue

    if [[ ! -d "${path}" ]]; then
      echo "❌ Missing kustomize path: ${path} (from ${flux_file})"
      fail=1
      continue
    fi

    if [[ "${SKIP_REMOTE}" == "1" ]]; then
      remote_found=0

      kfile="${path}/kustomization.yaml"
      if [[ -f "${kfile}" ]]; then
        while read -r res; do
          [[ -n "${res}" ]] || continue
          if [[ "${res}" =~ ^https?:// ]]; then
            remote_found=1
            break
          fi
          if [[ -d "${path}/${res}" ]]; then
            res_kfile="${path}/${res}/kustomization.yaml"
            if [[ -f "${res_kfile}" ]]; then
              if rg -n "^[[:space:]]*-[[:space:]]*https?://" "${res_kfile}" >/dev/null 2>&1; then
                remote_found=1
                break
              fi
            fi
          fi
        done < <(rg "^[[:space:]]*-[[:space:]]*" "${kfile}" | sed -E 's/^[[:space:]]*-[[:space:]]*//')
      fi

      if [[ "${remote_found}" -eq 1 ]]; then
        echo "⚠️  Skipping ${path} (remote resources detected; set SKIP_REMOTE=0 to render)"
        continue
      fi
    fi

    echo "Building ${path}"
    if ! kustomize build "${path}" >/tmp/kustomize-build.out 2>/tmp/kustomize-build.err; then
      echo "❌ kustomize build failed for ${path} (from ${flux_file})"
      cat /tmp/kustomize-build.err
      fail=1
    fi
  done < <(rg "^[[:space:]]*path:" "${flux_file}" | sed -E 's/^.*path:[[:space:]]*//')
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "✅ kustomize build checks passed"
