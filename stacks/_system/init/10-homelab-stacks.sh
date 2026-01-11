#!/usr/bin/env bash
set -euo pipefail

# Deploy all homelab stacks on TrueNAS boot
# Note: Intentionally duplicated from cron script for clarity and independence

SYNC_AND_DEPLOY_PATH="${HOMELAB_STACKS_SYNC_AND_DEPLOY_PATH:-/mnt/apps01/appdata/stacks/homelab/stacks/_bin/sync-and-deploy}"

# Run async in background to avoid blocking boot.
# Timeout prevents indefinite hang if GitHub is unreachable.
if command -v timeout >/dev/null 2>&1; then
  timeout 300 "${SYNC_AND_DEPLOY_PATH}" >>/var/log/homelab-sync-and-deploy.log 2>&1 &
else
  "${SYNC_AND_DEPLOY_PATH}" >>/var/log/homelab-sync-and-deploy.log 2>&1 &
fi
