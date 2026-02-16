#!/bin/sh
###############################################################################
# PXE Stack — Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites for the PXE/Matchbox stack.
#          Creates the assets directory and downloads Debian netboot
#          files if missing.
# Tier: Infrastructure
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
#
# NOTE: This script runs inside the Periphery container, which does NOT
# have /mnt/apps01/appdata mounted. All host-path operations (mkdir,
# curl, chmod) are executed via a helper `docker run` so they land on
# the actual host filesystem.
###############################################################################

set -eu

ASSETS_PATH="${ASSETS_PATH:-/mnt/apps01/appdata/pxe/assets}"
DEBIAN_MIRROR="https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64"

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

# Download Debian 12 netboot assets via a helper container so files
# land on the host filesystem (Periphery only mounts /mnt/apps01/repos).
log "Ensuring Debian 12 netboot assets on host..."
docker run --rm \
    -v "${ASSETS_PATH}:/assets" \
    alpine/curl:latest sh -c "
        set -eu
        mkdir -p /assets/debian-12
        cd /assets/debian-12
        if [ ! -s linux ]; then
            echo '[pxe-validation] Downloading kernel...'
            curl -fsSL '${DEBIAN_MIRROR}/linux' -o linux
        else
            echo '[pxe-validation] Kernel present'
        fi
        if [ ! -s initrd.gz ]; then
            echo '[pxe-validation] Downloading initrd...'
            curl -fsSL '${DEBIAN_MIRROR}/initrd.gz' -o initrd.gz
        else
            echo '[pxe-validation] Initrd present'
        fi
        # Verify
        for f in linux initrd.gz; do
            if [ ! -s \"\$f\" ]; then
                echo \"[pxe-validation] ERROR: \$f missing or empty\" >&2
                exit 1
            fi
        done
        echo '[pxe-validation] Assets verified'
        chmod -R 755 /assets
    "

log "PXE stack validation complete"
