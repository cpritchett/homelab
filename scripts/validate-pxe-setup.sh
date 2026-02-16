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
DEBIAN_MIRROR="https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64"

mkdir -p "${DEBIAN_ASSETS}"

if [ ! -s "${DEBIAN_ASSETS}/linux" ]; then
    log "Downloading Debian 12 netboot kernel..."
    curl -fsSL "${DEBIAN_MIRROR}/linux" -o "${DEBIAN_ASSETS}/linux"
    log "Kernel downloaded"
else
    log "Debian 12 netboot kernel present"
fi

if [ ! -s "${DEBIAN_ASSETS}/initrd.gz" ]; then
    log "Downloading Debian 12 netboot initrd..."
    curl -fsSL "${DEBIAN_MIRROR}/initrd.gz" -o "${DEBIAN_ASSETS}/initrd.gz"
    log "Initrd downloaded"
else
    log "Debian 12 netboot initrd present"
fi

# Final verification
for f in "${DEBIAN_ASSETS}/linux" "${DEBIAN_ASSETS}/initrd.gz"; do
    if [ ! -s "$f" ]; then
        log_error "Asset file is missing or empty after download: $f"
        exit 1
    fi
done

log "Debian 12 netboot assets verified"

# Ensure assets directory permissions
chmod -R 755 "${ASSETS_PATH}"
log "Asset directory permissions set"

log "PXE stack validation complete"
