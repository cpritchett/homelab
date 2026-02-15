#!/bin/sh
###############################################################################
# Download Matchbox Assets — Debian 12 Netboot
#
# Purpose: Download Debian 12 netboot kernel and initrd to the Matchbox
#          assets directory on barbary. Run once before first PXE boot.
#
# Usage:   ssh truenas_admin@barbary "sudo sh download-matchbox-assets.sh"
#
# Assets are stored at /mnt/apps01/appdata/pxe/assets/debian-12/
# and mounted read-only into the Matchbox container.
###############################################################################

set -eu

ASSETS_DIR="/mnt/apps01/appdata/pxe/assets/debian-12"
DEBIAN_MIRROR="https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64"

log() {
    echo "[matchbox-assets] $*"
}

log_error() {
    echo "[matchbox-assets] ERROR: $*" >&2
}

# Create assets directory
mkdir -p "$ASSETS_DIR"

# Download kernel
if [ -f "${ASSETS_DIR}/linux" ]; then
    log "Kernel already exists at ${ASSETS_DIR}/linux"
else
    log "Downloading Debian 12 netboot kernel..."
    curl -fsSL "${DEBIAN_MIRROR}/linux" -o "${ASSETS_DIR}/linux"
    log "Kernel downloaded"
fi

# Download initrd
if [ -f "${ASSETS_DIR}/initrd.gz" ]; then
    log "Initrd already exists at ${ASSETS_DIR}/initrd.gz"
else
    log "Downloading Debian 12 netboot initrd..."
    curl -fsSL "${DEBIAN_MIRROR}/initrd.gz" -o "${ASSETS_DIR}/initrd.gz"
    log "Initrd downloaded"
fi

# Verify files
for f in linux initrd.gz; do
    if [ ! -s "${ASSETS_DIR}/${f}" ]; then
        log_error "${ASSETS_DIR}/${f} is missing or empty"
        exit 1
    fi
done

log "Debian 12 netboot assets ready at ${ASSETS_DIR}/"
ls -lh "${ASSETS_DIR}/"
