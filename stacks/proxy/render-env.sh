#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Render via 1Password CLI (containerized) -> writes .env as current host user
/mnt/apps01/appdata/bin/op-inject inject -i .env.tpl > .env && chmod 600 .env && echo "Rendered .env in $(pwd)"
