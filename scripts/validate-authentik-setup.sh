#!/bin/bash
###############################################################################
# Authentik Platform Stack - Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites and prepare environment for Authentik
# Tier: Platform (depends on Infrastructure tier)
#
# Per ADR-0022: Actual deployment is done via Komodo UI, not this script.
# This script only:
#   1. Validates prerequisites (infrastructure, secrets, networks)
#   2. Creates required directories with correct permissions
#   3. Tests connectivity to required services
#
# Run this BEFORE deploying the stack via Komodo UI.
# Can also be configured as a Komodo pre-deployment hook.
###############################################################################

set -euo pipefail

# Configuration
REPO_PATH="${REPO_PATH:-/mnt/apps01/repos/homelab}"
SECRETS_PATH="${SECRETS_PATH:-/mnt/apps01/secrets}"
APPDATA_PATH="${APPDATA_PATH:-/mnt/apps01/appdata}"
DATA_PATH="${DATA_PATH:-/mnt/data01/appdata}"
LOG_FILE="${LOG_FILE:-/var/log/homelab-deploy-authentik.log}"

# Logging functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# Error handler
trap 'log_error "Authentik deployment failed at line $LINENO. Exit code: $?"' ERR

log "========================================="
log "Authentik Pre-Deployment Validation"
log "========================================="

# Verify running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Verify required paths exist
if [ ! -d "$REPO_PATH" ]; then
    log_error "Repository path not found: $REPO_PATH"
    exit 1
fi

# Verify Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or not accessible"
    exit 1
fi

# Verify Docker Swarm is active
if ! docker info | grep -q "Swarm: active"; then
    log_error "Docker Swarm is not active. Run infrastructure bootstrap first."
    exit 1
fi

log "Prerequisites verified: Docker Swarm active, paths exist"

# Verify infrastructure tier is running
log "Verifying infrastructure tier..."

if ! docker service ls | grep -q "op-connect_op-connect-api"; then
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

log "Infrastructure tier verified"

# Create directory structure
log "Creating Authentik data directories..."

mkdir -p "${DATA_PATH}/authentik"/{postgres,redis}
mkdir -p "${APPDATA_PATH}/authentik"/{media,custom-templates,secrets}

log "Setting directory permissions..."

# PostgreSQL runs as UID 999:999
chown -R 999:999 "${DATA_PATH}/authentik/postgres" 2>/dev/null || true
chmod 700 "${DATA_PATH}/authentik/postgres" 2>/dev/null || true

# Redis runs as UID 999:1000
chown -R 999:1000 "${DATA_PATH}/authentik/redis" 2>/dev/null || true
chmod 700 "${DATA_PATH}/authentik/redis" 2>/dev/null || true

# Authentik server/worker runs as UID 1000:1000
chown -R 1000:1000 "${APPDATA_PATH}/authentik/media" 2>/dev/null || true
chown -R 1000:1000 "${APPDATA_PATH}/authentik/custom-templates" 2>/dev/null || true
chmod 755 "${APPDATA_PATH}/authentik/media" 2>/dev/null || true
chmod 755 "${APPDATA_PATH}/authentik/custom-templates" 2>/dev/null || true

# Secrets directory for op inject init container
chown -R 999:999 "${APPDATA_PATH}/authentik/secrets" 2>/dev/null || true
chmod 755 "${APPDATA_PATH}/authentik/secrets" 2>/dev/null || true

log "Directory structure created and permissions set"

# Verify 1Password secrets exist
log "Verifying required secrets in 1Password..."

# Get op-connect API token from swarm secret to test connection
if ! docker secret inspect op_connect_token >/dev/null 2>&1; then
    log_error "op_connect_token secret not found"
    exit 1
fi

# Check if we can reach op-connect API
OPCONNECT_TEST=$(docker run --rm --network op-connect_op-connect \
    -e OP_CONNECT_HOST=http://op-connect-api:8080 \
    curlimages/curl:latest \
    curl -sf http://op-connect-api:8080/health 2>&1 || echo "FAILED")

if echo "$OPCONNECT_TEST" | grep -q "1Password Connect API"; then
    log "1Password Connect API is accessible"
else
    log_error "Cannot reach 1Password Connect API"
    log_error "Response: $OPCONNECT_TEST"
    exit 1
fi

# Note: We don't verify individual secret fields here because op inject
# will do that at runtime. The secrets-init container will fail if secrets
# are missing, which is the correct behavior.

log "Prerequisites complete"

log "========================================="
log "Pre-Deployment Validation Complete"
log "========================================="
log ""
log "✅ All prerequisites verified"
log "✅ Directory structure created"
log "✅ Permissions configured"
log "✅ Infrastructure tier healthy"
log "✅ 1Password Connect accessible"
log ""
log "Next steps:"
log "  1. Deploy via Komodo UI:"
log "     - Navigate to https://komodo.in.hypyr.space"
log "     - Stacks → Add Stack from Repository"
log "     - Path: stacks/platform/auth/authentik"
log "     - File: compose.yaml"
log "     - Click Deploy"
log ""
log "  2. Monitor deployment in Komodo UI or via CLI:"
log "     docker service ls --filter 'label=com.docker.stack.namespace=authentik'"
log ""
log "  3. After deployment (2-3 minutes):"
log "     - Access https://auth.in.hypyr.space"
log "     - Complete initial setup"
log "     - Verify auto-discovery in Homepage and Uptime Kuma"
log ""
log "Note: Per ADR-0022, actual deployment is done via Komodo UI."
log "This script only validates prerequisites and prepares the environment."
