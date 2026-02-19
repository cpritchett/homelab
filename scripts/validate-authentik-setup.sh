#!/bin/sh
###############################################################################
# Authentik Platform Stack - Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites and prepare environment for Authentik
# Tier: Platform (depends on Infrastructure tier)
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
#
# This script:
#   1. Validates prerequisites (infrastructure, secrets, networks)
#   2. Creates required directories with correct permissions (if not exists)
#   3. Tests connectivity to required services
#   4. Does NOT pull from git (Komodo handles git sync)
#   5. Does NOT deploy the stack (Komodo handles deployment)
#
# POSIX-compatible: Works with sh, bash, dash, etc.
###############################################################################

set -eu

# Configuration
APPDATA_PATH="${APPDATA_PATH:-/mnt/apps01/appdata}"

# Logging functions (quiet mode - only errors and critical info)
log() {
    echo "[authentik-validation] $*"
}

log_error() {
    echo "[authentik-validation] ERROR: $*" >&2
}

# Verify running as root (POSIX-compatible)
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Verify Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or not accessible"
    exit 1
fi

# Verify Docker Swarm is active
if ! docker info | grep -q "Swarm: active"; then
    log_error "Docker Swarm is not active. Deploy infrastructure tier first."
    exit 1
fi

# Verify infrastructure tier is running
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

if ! docker secret inspect CLOUDFLARE_API_TOKEN >/dev/null 2>&1; then
    log_error "CLOUDFLARE_API_TOKEN secret not found. Deploy infrastructure tier first."
    exit 1
fi

# Helper function to create directory with ownership if it doesn't exist
ensure_dir_with_ownership() {
    local dir="$1"
    local owner="$2"
    local perms="$3"

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chown "$owner" "$dir"
        chmod "$perms" "$dir"
        log "Created: $dir (${owner}, ${perms})"
    else
        # Directory exists - check if ownership/perms need updating
        local current_owner=$(stat -c '%u:%g' "$dir" 2>/dev/null || stat -f '%u:%g' "$dir" 2>/dev/null)
        local current_perms=$(stat -c '%a' "$dir" 2>/dev/null || stat -f '%Lp' "$dir" 2>/dev/null)

        if [ "$current_owner" != "$owner" ]; then
            chown "$owner" "$dir"
            log "Updated ownership: $dir → $owner"
        fi

        if [ "$current_perms" != "$perms" ]; then
            chmod "$perms" "$dir"
            log "Updated permissions: $dir → $perms"
        fi
    fi
}

# Create directory structure with correct ownership
# PostgreSQL runs as UID 999:999
ensure_dir_with_ownership "${APPDATA_PATH}/authentik/postgres" "999:999" "700"

# Redis runs as UID 999:1000
ensure_dir_with_ownership "${APPDATA_PATH}/authentik/redis" "999:1000" "700"

# Authentik server/worker runs as UID 1000:1000
ensure_dir_with_ownership "${APPDATA_PATH}/authentik" "root:root" "755"
ensure_dir_with_ownership "${APPDATA_PATH}/authentik/media" "1000:1000" "755"
ensure_dir_with_ownership "${APPDATA_PATH}/authentik/custom-templates" "1000:1000" "755"

# Secrets directory for op inject init container (UID 999:999)
# Authentik/postgres get access via group_add 999
ensure_dir_with_ownership "${APPDATA_PATH}/authentik/secrets" "999:999" "750"

# Blueprints directory for rendered blueprint templates
# Owned by UID 999:999 (op container writes here); authentik gets access via group_add 999
ensure_dir_with_ownership "${APPDATA_PATH}/authentik/blueprints" "999:999" "750"

# Quick connectivity test to 1Password Connect (fail fast if unreachable)
if ! docker run --rm --network op-connect_op-connect \
    -e OP_CONNECT_HOST=http://op-connect-api:8080 \
    curlimages/curl:latest \
    curl -sf -m 5 http://op-connect-api:8080/health >/dev/null 2>&1; then
    log_error "Cannot reach 1Password Connect API at http://op-connect-api:8080/health"
    exit 1
fi

log "✅ Pre-deployment validation complete"
exit 0
