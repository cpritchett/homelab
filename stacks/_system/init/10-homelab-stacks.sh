#!/usr/bin/env bash
set -euo pipefail

# Deploy all homelab stacks on TrueNAS boot
# Note: Intentionally duplicated from cron script for clarity and independence

SYNC_AND_DEPLOY_PATH="${HOMELAB_STACKS_SYNC_AND_DEPLOY_PATH:-/mnt/apps01/appdata/stacks/homelab/stacks/_bin/sync-and-deploy}"

if command -v timeout >/dev/null 2>&1; then
  if ! timeout 300 "${SYNC_AND_DEPLOY_PATH}" >>/var/log/homelab-sync-and-deploy.log 2>&1 & then
    echo "Failed to start homelab sync-and-deploy with timeout" >&2
  fi
else
  if ! "${SYNC_AND_DEPLOY_PATH}" >>/var/log/homelab-sync-and-deploy.log 2>&1 & then
    echo "Failed to start homelab sync-and-deploy (no timeout available)" >&2
  fi
fi
