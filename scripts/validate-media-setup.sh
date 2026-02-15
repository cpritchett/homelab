#!/bin/sh
###############################################################################
# Media Stack - Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites and prepare host paths for
#          media application stacks (core, support, torrent).
# Tier: Application (depends on Infrastructure + Platform tiers)
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
###############################################################################

set -eu

APPDATA_PATH="${APPDATA_PATH:-/mnt/apps01/appdata}"
DATA_PATH="${DATA_PATH:-/mnt/data01/data}"
MEDIA_UID="1701"
MEDIA_GID="1702"
MEDIA_OWNER="${MEDIA_UID}:${MEDIA_GID}"

log() {
    echo "[media-validation] $*"
}

log_error() {
    echo "[media-validation] ERROR: $*" >&2
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

# ---------------------------------------------------------------------------
# Directory setup helper (same pattern as validate-monitoring-setup.sh)
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Application config directories (apps01 — fast tier)
# ---------------------------------------------------------------------------

for svc in plex sonarr radarr prowlarr sabnzbd bazarr tautulli maintainerr seerr; do
    ensure_dir_with_ownership "${APPDATA_PATH}/media/${svc}/config" "${MEDIA_OWNER}" "755"
done

# Secrets directories for stacks that use 1Password hydration
for stack in core torrent support; do
    ensure_dir_with_ownership "${APPDATA_PATH}/media/${stack}/secrets" "999:999" "755"
done

# ---------------------------------------------------------------------------
# Media data directories (data01 — bulk tier)
# ---------------------------------------------------------------------------

ensure_dir_with_ownership "${DATA_PATH}/downloads/complete" "${MEDIA_OWNER}" "755"
ensure_dir_with_ownership "${DATA_PATH}/downloads/incomplete" "${MEDIA_OWNER}" "755"
ensure_dir_with_ownership "${DATA_PATH}/media/tv" "${MEDIA_OWNER}" "755"
ensure_dir_with_ownership "${DATA_PATH}/media/movies" "${MEDIA_OWNER}" "755"
ensure_dir_with_ownership "${DATA_PATH}/media/music" "${MEDIA_OWNER}" "755"

# ---------------------------------------------------------------------------
# GPU device check (Plex hardware transcoding)
# ---------------------------------------------------------------------------

if [ ! -d /dev/dri ]; then
    log "WARNING: /dev/dri not found — Plex hardware transcoding will not be available"
else
    log "/dev/dri exists — GPU passthrough available for Plex"
fi

# ---------------------------------------------------------------------------
# 1Password Connect reachability
# ---------------------------------------------------------------------------

if ! docker run --rm --network op-connect_op-connect \
    -e OP_CONNECT_HOST=http://op-connect-api:8080 \
    curlimages/curl:latest \
    curl -sf -m 5 http://op-connect-api:8080/health >/dev/null 2>&1; then
    log_error "Cannot reach 1Password Connect API at http://op-connect-api:8080/health"
    exit 1
fi

log "✅ Pre-deployment validation complete"
exit 0
