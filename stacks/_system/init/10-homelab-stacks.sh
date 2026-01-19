#!/usr/bin/env bash
set -euo pipefail

# Optional bootstrap script for TrueNAS init
# Komodo is the primary reconciler; this is a failsafe fallback only
# 
# This script runs sync-and-deploy in background with timeout and logging
# Use only if Komodo is not available or as emergency bootstrap

LOG_DIR="/mnt/apps01/appdata/logs/stacks"
LOG_FILE="${LOG_DIR}/bootstrap.log"
SYNC_AND_DEPLOY_PATH="${HOMELAB_STACKS_SYNC_AND_DEPLOY_PATH:-/mnt/apps01/appdata/stacks/checkout/stacks/_bin/sync-and-deploy}"

# Create log directory
mkdir -p "${LOG_DIR}"

# Log with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log "INFO: TrueNAS bootstrap starting (Komodo failsafe)"

# Check if sync-and-deploy exists
if [[ ! -x "${SYNC_AND_DEPLOY_PATH}" ]]; then
  log "WARNING: sync-and-deploy not found at ${SYNC_AND_DEPLOY_PATH}"
  log "INFO: This is expected if Komodo manages deployments"
  exit 0
fi

# Run in background with timeout to avoid blocking boot
# 300 seconds should be sufficient for git sync + deploy
log "INFO: Starting sync-and-deploy in background (300s timeout)"

if command -v timeout >/dev/null 2>&1; then
  timeout 300 "${SYNC_AND_DEPLOY_PATH}" >>"${LOG_FILE}" 2>&1 &
  DEPLOY_PID=$!
  log "INFO: sync-and-deploy started with PID ${DEPLOY_PID}"
else
  "${SYNC_AND_DEPLOY_PATH}" >>"${LOG_FILE}" 2>&1 &
  DEPLOY_PID=$!
  log "WARNING: timeout command not available, running without timeout (PID ${DEPLOY_PID})"
fi

log "INFO: TrueNAS bootstrap completed, deployment running in background"
