#!/usr/bin/env bash
set -euo pipefail

RUN_HELM_TEMPLATE="${RUN_HELM_TEMPLATE:-0}"

if ! command -v helm >/dev/null 2>&1; then
  echo "⚠️  helm not installed; running reference checks only"
  RUN_HELM_TEMPLATE=0
fi

# Build HelmRepository map: name -> url
mapfile -t helmrepo_files < <(rg -l "^kind: HelmRepository$" -S kubernetes || true)

declare -A helmrepo_url
for f in "${helmrepo_files[@]}"; do
  awk '
    /^---$/ {if(kind=="HelmRepository" && name!="" && url!=""){print name "|" url} kind=""; name=""; url=""; in_meta=0; in_spec=0; next}
    /^kind:/ {kind=$2; in_meta=0; in_spec=0}
    /^metadata:/ {in_meta=1; in_spec=0; next}
    in_meta && $1=="name:" && name=="" {name=$2}
    /^spec:/ {in_spec=1; in_meta=0; next}
    in_spec && $1=="url:" && url=="" {url=$2}
    END {if(kind=="HelmRepository" && name!="" && url!=""){print name "|" url}}
  ' "$f" | while IFS='|' read -r name url; do
    helmrepo_url["$name"]="$url"
  done
done

# Build OCIRepository map: name -> url|tag
mapfile -t ocirepo_files < <(rg -l "^kind: OCIRepository$" -S kubernetes || true)

declare -A ocirepo_url
declare -A ocirepo_tag
for f in "${ocirepo_files[@]}"; do
  awk '
    /^---$/ {if(kind=="OCIRepository" && name!="" && url!=""){print name "|" url "|" tag} kind=""; name=""; url=""; tag=""; in_meta=0; in_spec=0; next}
    /^kind:/ {kind=$2; in_meta=0; in_spec=0}
    /^metadata:/ {in_meta=1; in_spec=0; next}
    in_meta && $1=="name:" && name=="" {name=$2}
    /^spec:/ {in_spec=1; in_meta=0; next}
    in_spec && $1=="url:" && url=="" {url=$2}
    in_spec && $1=="tag:" && tag=="" {tag=$2}
    END {if(kind=="OCIRepository" && name!="" && url!=""){print name "|" url "|" tag}}
  ' "$f" | while IFS='|' read -r name url tag; do
    ocirepo_url["$name"]="$url"
    ocirepo_tag["$name"]="$tag"
  done
done

mapfile -t helmrelease_files < <(rg -l "^kind: HelmRelease$" -S kubernetes || true)

if [[ ${#helmrelease_files[@]} -eq 0 ]]; then
  echo "⚠️  No HelmRelease files found"
  exit 0
fi

fail=0

for f in "${helmrelease_files[@]}"; do
  awk '
    BEGIN {FS=": *"}
    /^---$/ {
      if(kind=="HelmRelease"){
        print hr_name "|" hr_ns "|" cr_kind "|" cr_name "|" chart "|" version "|" src_kind "|" src_name
      }
      kind=""; hr_name=""; hr_ns=""; cr_kind=""; cr_name=""; chart=""; version=""; src_kind=""; src_name=""; in_meta=0; in_chartref=0; in_chartspec=0; in_sourceref=0; next
    }
    /^kind:/ {kind=$2; in_meta=0; in_chartref=0; in_chartspec=0; in_sourceref=0}
    /^metadata:/ {in_meta=1; next}
    in_meta && $1=="name" && hr_name=="" {hr_name=$2}
    in_meta && $1=="namespace" && hr_ns=="" {hr_ns=$2}
    /^chartRef:/ {in_chartref=1; in_chartspec=0; in_sourceref=0; next}
    in_chartref && $1=="kind" && cr_kind=="" {cr_kind=$2}
    in_chartref && $1=="name" && cr_name=="" {cr_name=$2}
    /^chart:/ {if(kind=="HelmRelease"){in_chartspec=1; in_chartref=0; in_sourceref=0; next}}
    in_chartspec && $1=="chart" && chart=="" {chart=$2}
    in_chartspec && $1=="version" && version=="" {version=$2}
    in_chartspec && $1=="sourceRef" {in_sourceref=1; next}
    in_sourceref && $1=="kind" && src_kind=="" {src_kind=$2}
    in_sourceref && $1=="name" && src_name=="" {src_name=$2}
    END {if(kind=="HelmRelease"){print hr_name "|" hr_ns "|" cr_kind "|" cr_name "|" chart "|" version "|" src_kind "|" src_name}}
  ' "$f" | while IFS='|' read -r name ns cr_kind cr_name chart version src_kind src_name; do
    if [[ -z "${name}" ]]; then
      continue
    fi

    if [[ -z "${cr_kind}${chart}" ]]; then
      echo "❌ ${f}: HelmRelease ${name} missing chartRef or chart spec"
      fail=1
      continue
    fi

    if [[ "${cr_kind}" == "OCIRepository" ]]; then
      if [[ -z "${ocirepo_url[$cr_name]:-}" ]]; then
        echo "❌ ${f}: HelmRelease ${name} references OCIRepository ${cr_name} but none found"
        fail=1
      else
        echo "✓ ${f}: HelmRelease ${name} -> OCIRepository ${cr_name}"
      fi
    fi

    if [[ "${src_kind}" == "HelmRepository" ]]; then
      if [[ -z "${helmrepo_url[$src_name]:-}" ]]; then
        echo "❌ ${f}: HelmRelease ${name} references HelmRepository ${src_name} but none found"
        fail=1
      else
        echo "✓ ${f}: HelmRelease ${name} -> HelmRepository ${src_name}"
      fi
    fi

    if [[ "${RUN_HELM_TEMPLATE}" == "1" && -n "${chart}" ]]; then
      echo "⚠️  Template rendering not implemented for ${name} (best-effort reference checks only)"
    fi
  done
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

echo "✅ HelmRelease reference checks passed"
