#!/usr/bin/env bash
set -euo pipefail

# Deploy all homelab stacks on schedule (cron)
# Note: Intentionally duplicated from init script for clarity and independence

# Prevent concurrent runs from cron using a non-blocking flock
LOCK_FILE="/tmp/deploy-stacks.lock"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "deploy-stacks: another deployment is already running, exiting." >&2
  exit 0
fi

SYNC_AND_DEPLOY_PATH="${SYNC_AND_DEPLOY_PATH:-/mnt/apps01/appdata/stacks/homelab/stacks/_bin/sync-and-deploy}"
"${SYNC_AND_DEPLOY_PATH}"
