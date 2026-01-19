#!/usr/bin/env bash
set -euo pipefail

# Render .env from .env.tpl using 1Password injection
# This script is called by deploy-stack if both render-env.sh and .env.tpl exist

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ ! -f .env.tpl ]]; then
  echo "ERROR: .env.tpl not found in $(pwd)" >&2
  exit 1
fi

# Use op-inject from the global bin directory or local _bin
OP_INJECT_CMD="/mnt/apps01/appdata/bin/op-inject"
if [[ ! -x "${OP_INJECT_CMD}" ]]; then
  OP_INJECT_CMD="../_bin/op-inject"
fi

if [[ ! -x "${OP_INJECT_CMD}" ]]; then
  echo "ERROR: op-inject not found at ${OP_INJECT_CMD}" >&2
  exit 1
fi

echo "Rendering .env from .env.tpl using 1Password..."
"${OP_INJECT_CMD}" inject .env.tpl

if [[ -f .env ]]; then
  echo "Successfully rendered .env"
  chmod 600 .env
else
  echo "ERROR: .env was not created" >&2
  exit 1
fi
