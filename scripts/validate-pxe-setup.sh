#!/bin/sh
###############################################################################
# PXE Stack — Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites for the PXE/Matchbox stack.
#          Checks that Debian netboot assets are downloaded and the
#          required directory structure exists.
# Tier: Infrastructure
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
###############################################################################

set -eu

ASSETS_PATH="${ASSETS_PATH:-/mnt/apps01/appdata/pxe/assets}"

log() {
    echo "[pxe-validation] $*"
}

log_error() {
    echo "[pxe-validation] ERROR: $*" >&2
}

# Root check
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Docker + Swarm checks
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or not accessible"
    exit 1
fi

if ! docker info | grep -q "Swarm: active"; then
    log_error "Docker Swarm is not active"
    exit 1
fi

# Infrastructure dependencies
if ! docker network inspect proxy_network >/dev/null 2>&1; then
    log_error "proxy_network not found. Deploy infrastructure tier first."
    exit 1
fi

# Debian 12 netboot assets
DEBIAN_ASSETS="${ASSETS_PATH}/debian-12"

if [ ! -f "${DEBIAN_ASSETS}/linux" ]; then
    log_error "Debian netboot kernel not found at ${DEBIAN_ASSETS}/linux"
    log_error "Run: scripts/download-matchbox-assets.sh"
    exit 1
fi

if [ ! -f "${DEBIAN_ASSETS}/initrd.gz" ]; then
    log_error "Debian netboot initrd not found at ${DEBIAN_ASSETS}/initrd.gz"
    log_error "Run: scripts/download-matchbox-assets.sh"
    exit 1
fi

# Verify files are not empty
for f in "${DEBIAN_ASSETS}/linux" "${DEBIAN_ASSETS}/initrd.gz"; do
    if [ ! -s "$f" ]; then
        log_error "Asset file is empty: $f"
        exit 1
    fi
done

log "Debian 12 netboot assets verified"

# Ensure assets directory permissions
chmod -R 755 "${ASSETS_PATH}"
log "Asset directory permissions set"

log "PXE stack validation complete"
