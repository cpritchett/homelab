#!/bin/sh
###############################################################################
# PXE Stack — Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites for the PXE/Matchbox stack.
#          Creates the repo-served assets directory, downloads Debian
#          netboot files, and builds Broadside assets when enabled.
# Tier: Infrastructure
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
#
# NOTE: This script runs inside the Periphery container. Host filesystem
# writes for served PXE assets happen either under the repo checkout or
# through helper containers so files land on the actual host filesystem.
###############################################################################

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ASSETS_PATH="${ASSETS_PATH:-${REPO_ROOT}/stacks/infrastructure/pxe/assets}"
DEBIAN_MIRROR="https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64"
BROADSIDE_ASSETS_PATH="${BROADSIDE_ASSETS_PATH:-${ASSETS_PATH}/broadside}"
PXE_ENABLE_BROADSIDE="${PXE_ENABLE_BROADSIDE:-0}"
BROADSIDE_DNSMASQ_RENDERED="${REPO_ROOT}/stacks/infrastructure/pxe/dnsmasq.d/broadside.conf"
BROADSIDE_MATCHBOX_RENDERED="${REPO_ROOT}/stacks/infrastructure/pxe/matchbox/groups/broadside.json"

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

mkdir -p "${ASSETS_PATH}/debian-12" "${BROADSIDE_ASSETS_PATH}"

# Download Debian 12 netboot assets via a helper container so files
# land on the repo-served host filesystem.
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

if [ "${PXE_ENABLE_BROADSIDE}" = "1" ]; then
    log "Rendering Broadside PXE host inventory from 1Password..."
    (
        cd "${REPO_ROOT}"
        ./scripts/render-broadside-pxe-config.sh
    )

    if [ ! -s "${BROADSIDE_DNSMASQ_RENDERED}" ] || [ ! -s "${BROADSIDE_MATCHBOX_RENDERED}" ]; then
        log_error "Broadside PXE config render failed."
        exit 1
    fi

    log "Building Broadside NixOS netboot assets from repo checkout..."
    (
        cd "${REPO_ROOT}"
        ./scripts/build-broadside-installer-assets.sh "${BROADSIDE_ASSETS_PATH}"
    )

    log "Validating Broadside NixOS netboot assets on host..."
    docker run --rm \
        -v "${BROADSIDE_ASSETS_PATH}:/assets" \
        alpine:latest sh -c "
            set -eu
            for f in netboot.ipxe bzImage initrd homelab.tar.gz nixpkgs.tar.gz disko.tar.gz; do
                if [ ! -s \"/assets/\$f\" ]; then
                    echo \"[pxe-validation] ERROR: missing Broadside asset \$f\" >&2
                    exit 1
                fi
            done
            echo '[pxe-validation] Broadside assets verified'
        "
else
    log "Skipping Broadside asset validation (set PXE_ENABLE_BROADSIDE=1 to require it)"
fi

log "PXE stack validation complete"
