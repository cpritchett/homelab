#!/bin/sh
###############################################################################
# Shared PostgreSQL Stack - Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites and prepare host paths for PostgreSQL.
# Tier: Platform (depends on Infrastructure tier)
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
###############################################################################

set -eu

APPDATA_PATH="${APPDATA_PATH:-/mnt/apps01/appdata}"

log() {
    echo "[postgres-validation] $*"
}

log_error() {
    echo "[postgres-validation] ERROR: $*" >&2
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

if ! docker network inspect op-connect_op-connect >/dev/null 2>&1; then
    log_error "op-connect network not found. Deploy infrastructure tier first."
    exit 1
fi

if ! docker secret inspect op_connect_token >/dev/null 2>&1; then
    log_error "op_connect_token secret not found. Deploy infrastructure tier first."
    exit 1
fi

# ---------------------------------------------------------------------------
# Directory setup helper
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
# Directories
# ---------------------------------------------------------------------------

# Secrets directory (written by 1password/op:2 as opuser 999:999)
ensure_dir_with_ownership "${APPDATA_PATH}/postgres/secrets" "999:999" "750"

# Backup directory (written by pg_dump as root)
ensure_dir_with_ownership "${APPDATA_PATH}/postgres/backups" "root:root" "755"

# PostgreSQL data directory (postgres runs as UID 70 in alpine image)
ensure_dir_with_ownership "${APPDATA_PATH}/postgres/data" "70:70" "700"

log "Pre-deployment validation complete"
exit 0
