#!/bin/sh
###############################################################################
# Cloudflare Tunnel - Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites and prepare host paths for
#          Cloudflare Tunnel stack.
# Tier: Platform (depends on Infrastructure tier)
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
###############################################################################

set -eu

APPDATA_PATH="${APPDATA_PATH:-/mnt/apps01/appdata}"

log() {
    echo "[cloudflared-validation] $*"
}

log_error() {
    echo "[cloudflared-validation] ERROR: $*" >&2
}

if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or not accessible"
    exit 1
fi

if ! docker info | grep -q "Swarm: active"; then
    log_error "Docker Swarm is not active"
    exit 1
fi

if ! docker service ls 2>/dev/null | grep -q "op-connect_op-connect-api"; then
    log_error "1Password Connect is not running. Deploy infrastructure tier first."
    exit 1
fi

if ! docker network inspect proxy_network >/dev/null 2>&1; then
    log_error "proxy_network not found. Deploy infrastructure tier first."
    exit 1
fi

if ! docker network inspect op-connect_op-connect >/dev/null 2>&1; then
    log_error "op-connect network not found. Deploy infrastructure tier first."
    exit 1
fi

if ! docker secret inspect op_connect_token >/dev/null 2>&1; then
    log_error "op_connect_token secret not found. Deploy infrastructure tier first."
    exit 1
fi

ensure_dir_with_ownership() {
    dir="$1"
    owner="$2"
    perms="$3"

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chown "$owner" "$dir"
        chmod "$perms" "$dir"
        log "Created: $dir (${owner}, ${perms})"
        return
    fi

    current_owner=$(stat -c '%u:%g' "$dir" 2>/dev/null || stat -f '%u:%g' "$dir" 2>/dev/null)
    current_perms=$(stat -c '%a' "$dir" 2>/dev/null || stat -f '%Lp' "$dir" 2>/dev/null)

    if [ "$current_owner" != "$owner" ]; then
        chown "$owner" "$dir"
        log "Updated ownership: $dir -> $owner"
    fi

    if [ "$current_perms" != "$perms" ]; then
        chmod "$perms" "$dir"
        log "Updated permissions: $dir -> $perms"
    fi
}

ensure_dir_with_ownership "${APPDATA_PATH}/cloudflared" "root:root" "755"
ensure_dir_with_ownership "${APPDATA_PATH}/cloudflared/secrets" "65532:65532" "750"

if ! docker run --rm --network op-connect_op-connect \
    -e OP_CONNECT_HOST=http://op-connect-api:8080 \
    curlimages/curl:latest \
    curl -sf -m 5 http://op-connect-api:8080/health >/dev/null 2>&1; then
    log_error "Cannot reach 1Password Connect API at http://op-connect-api:8080/health"
    exit 1
fi

log "All prerequisites met"
exit 0
