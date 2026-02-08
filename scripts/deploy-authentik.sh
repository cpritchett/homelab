#!/bin/bash
###############################################################################
# Authentik Platform Stack Deployment Script
#
# Purpose: Deploy Authentik SSO platform on TrueNAS Docker Swarm
# Tier: Platform (depends on Infrastructure tier)
#
# Prerequisites:
#   - Infrastructure tier deployed (op-connect, komodo, caddy)
#   - 1Password Connect running
#   - Required secrets in 1Password vault
#
# This script is idempotent and safe to run multiple times.
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
log "Deploying Authentik SSO Platform"
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

# Deploy Authentik stack
log "========================================="
log "Deploying Authentik Stack"
log "========================================="

COMPOSE_FILE="${REPO_PATH}/stacks/platform/auth/authentik/compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Compose file not found: $COMPOSE_FILE"
    exit 1
fi

log "Deploying from: $COMPOSE_FILE"

if docker stack deploy -c "$COMPOSE_FILE" authentik; then
    log "Authentik stack deployed successfully"
else
    log_error "Failed to deploy Authentik stack"
    exit 1
fi

log "Waiting 30 seconds for secrets-init container to inject secrets..."
sleep 30

# Check if secrets were injected
if [ -f "${APPDATA_PATH}/authentik/secrets/authentik.env" ]; then
    log "Secrets injected successfully: authentik.env"
else
    log "Warning: authentik.env not found yet, may still be initializing"
fi

if [ -f "${APPDATA_PATH}/authentik/secrets/postgres.env" ]; then
    log "Secrets injected successfully: postgres.env"
else
    log "Warning: postgres.env not found yet, may still be initializing"
fi

log "Waiting 60 seconds for PostgreSQL and Redis to initialize..."
sleep 60

# Verify services are running
log "Verifying Authentik services..."

EXPECTED_SERVICES=(
    "authentik_secrets-init"
    "authentik_postgresql"
    "authentik_redis"
    "authentik_authentik-server"
    "authentik_authentik-worker"
)

ALL_RUNNING=true
for service in "${EXPECTED_SERVICES[@]}"; do
    if docker service ls --filter "name=$service" | grep -q "$service"; then
        STATUS=$(docker service ps "$service" --format "{{.CurrentState}}" --filter "desired-state=running" | head -1)
        log "Service $service: $STATUS"
    else
        log_error "Service $service not found"
        ALL_RUNNING=false
    fi
done

if [ "$ALL_RUNNING" = true ]; then
    log "All Authentik services deployed"
else
    log_error "Some Authentik services failed to start"
    log "Check service logs with: docker service logs authentik_<service-name>"
    exit 1
fi

log "========================================="
log "Authentik Deployment Complete"
log "========================================="
log ""
log "Next steps:"
log "  1. Wait 2-3 minutes for Authentik to fully initialize"
log "  2. Access https://auth.in.hypyr.space"
log "  3. Complete initial setup (akadmin user creation)"
log "  4. Check Homepage dashboard for Authentik widget"
log "  5. Check Uptime Kuma for Authentik monitor (auto-created via AutoKuma)"
log ""
log "Monitor deployment:"
log "  docker service ls --filter 'label=com.docker.stack.namespace=authentik'"
log "  docker service logs -f authentik_authentik-server"
log "  docker service logs -f authentik_postgresql"
log ""
log "Troubleshooting:"
log "  - Check secrets injection: ls -la ${APPDATA_PATH}/authentik/secrets/"
log "  - Check secrets-init logs: docker service logs authentik_secrets-init"
log "  - Check database: docker service logs authentik_postgresql"
log "  - Check Authentik logs: docker service logs authentik_authentik-server"
