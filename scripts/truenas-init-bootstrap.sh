#!/bin/bash
###############################################################################
# TrueNAS Scale Homelab Bootstrap Script
#
# Purpose: Initialize Docker Swarm infrastructure tier on TrueNAS boot
# Tier: Infrastructure (op-connect → komodo → caddy)
#
# This script is idempotent and safe to run multiple times.
# Intended to be called from systemd service or TrueNAS init/shutdown scripts.
###############################################################################

set -euo pipefail

# Configuration
REPO_PATH="${REPO_PATH:-/mnt/apps01/repos/homelab}"
SECRETS_PATH="${SECRETS_PATH:-/mnt/apps01/secrets}"
APPDATA_PATH="${APPDATA_PATH:-/mnt/apps01/appdata}"
LOG_FILE="${LOG_FILE:-/var/log/homelab-bootstrap.log}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# Error handler
trap 'log_error "Bootstrap failed at line $LINENO. Exit code: $?"' ERR

log "========================================="
log "Starting Homelab Infrastructure Bootstrap"
log "========================================="

# Verify running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Verify required paths exist
if [ ! -d "$REPO_PATH" ]; then
    log_error "Repository path not found: $REPO_PATH"
    log_error "Please clone the homelab repository to this location"
    exit 1
fi

if [ ! -d "$SECRETS_PATH" ]; then
    log_error "Secrets path not found: $SECRETS_PATH"
    log_error "Please create the secrets directory and populate with credentials"
    exit 1
fi

# Verify Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or not accessible"
    exit 1
fi

log "Verified prerequisites: Docker running, paths exist"

# Initialize Docker Swarm if needed
if ! docker info | grep -q "Swarm: active"; then
    log "Initializing Docker Swarm..."
    ADVERTISE_ADDR=$(hostname -I | awk '{print $1}')
    docker swarm init --advertise-addr "$ADVERTISE_ADDR"
    log "Docker Swarm initialized with advertise address: $ADVERTISE_ADDR"
else
    log "Docker Swarm already active"
fi

# Create overlay networks (idempotent)
log "Creating overlay networks..."

if ! docker network inspect proxy_network >/dev/null 2>&1; then
    docker network create --driver overlay --attachable proxy_network
    log "Created network: proxy_network"
else
    log "Network already exists: proxy_network"
fi

if ! docker network inspect op-connect_op-connect >/dev/null 2>&1; then
    docker network create --driver overlay --attachable op-connect_op-connect
    log "Created network: op-connect_op-connect"
else
    log "Network already exists: op-connect_op-connect"
fi

# Create Swarm secrets (idempotent)
log "Creating Swarm secrets..."

# op_connect_token
if [ -f "${SECRETS_PATH}/op/connect-token" ]; then
    if ! docker secret inspect op_connect_token >/dev/null 2>&1; then
        cat "${SECRETS_PATH}/op/connect-token" | docker secret create op_connect_token -
        log "Created secret: op_connect_token"
    else
        log "Secret already exists: op_connect_token"
    fi
else
    log_error "1Password Connect token not found: ${SECRETS_PATH}/op/connect-token"
    log_error "Please generate and save the token before running bootstrap"
    exit 1
fi

# CLOUDFLARE_API_TOKEN
if [ -f "${SECRETS_PATH}/cloudflare/api-token" ]; then
    if ! docker secret inspect CLOUDFLARE_API_TOKEN >/dev/null 2>&1; then
        cat "${SECRETS_PATH}/cloudflare/api-token" | docker secret create CLOUDFLARE_API_TOKEN -
        log "Created secret: CLOUDFLARE_API_TOKEN"
    else
        log "Secret already exists: CLOUDFLARE_API_TOKEN"
    fi
else
    log "Warning: Cloudflare API token not found: ${SECRETS_PATH}/cloudflare/api-token"
    log "Caddy TLS automation may not work without this"
fi

# Ensure directory structure exists
log "Creating application data directories..."

mkdir -p "${APPDATA_PATH}"/{op-connect,komodo,proxy}
mkdir -p "${APPDATA_PATH}/komodo"/{mongodb,sync,backups,secrets,periphery}
mkdir -p "${APPDATA_PATH}/proxy"/{caddy-data,caddy-config,caddy-secrets}

log "Setting directory permissions..."

# Caddy runs as 1701:1702
chown -R 1701:1702 "${APPDATA_PATH}/proxy" 2>/dev/null || true

# Komodo/MongoDB runs as 568:568
chown -R 568:568 "${APPDATA_PATH}/komodo" 2>/dev/null || true

log "Directory structure created and permissions set"

# Deploy infrastructure tier
log "========================================="
log "Deploying Infrastructure Tier"
log "========================================="

# 1. Deploy 1Password Connect (required by all other stacks for secrets)
log "Deploying op-connect stack..."
if docker stack deploy -c "${REPO_PATH}/stacks/infrastructure/op-connect-compose.yaml" op-connect; then
    log "op-connect stack deployed successfully"
else
    log_error "Failed to deploy op-connect stack"
    exit 1
fi

log "Waiting 30 seconds for op-connect to initialize..."
sleep 30

# Verify op-connect is healthy
if docker service ls --filter "name=op-connect" | grep -q "op-connect"; then
    log "op-connect services are running"
else
    log_error "op-connect services failed to start"
    exit 1
fi

# 2. Deploy Komodo (orchestration platform)
log "Deploying komodo stack..."
if docker stack deploy -c "${REPO_PATH}/stacks/infrastructure/komodo-compose.yaml" komodo; then
    log "komodo stack deployed successfully"
else
    log_error "Failed to deploy komodo stack"
    exit 1
fi

log "Waiting 45 seconds for MongoDB initialization and Komodo startup..."
sleep 45

# Verify komodo is healthy
if docker service ls --filter "name=komodo" | grep -q "komodo"; then
    log "komodo services are running"
else
    log_error "komodo services failed to start"
    exit 1
fi

# 3. Deploy Caddy (ingress/reverse proxy)
log "Deploying caddy stack..."
if docker stack deploy -c "${REPO_PATH}/stacks/infrastructure/caddy-compose.yaml" caddy; then
    log "caddy stack deployed successfully"
else
    log_error "Failed to deploy caddy stack"
    exit 1
fi

log "Waiting 15 seconds for Caddy to initialize..."
sleep 15

# Verify caddy is healthy
if docker service ls --filter "name=caddy" | grep -q "caddy"; then
    log "caddy services are running"
else
    log_error "caddy services failed to start"
    exit 1
fi

log "========================================="
log "Infrastructure Bootstrap Complete"
log "========================================="
log ""
log "Infrastructure tier is now running:"
log "  - 1Password Connect: http://op-connect-api:8080"
log "  - Komodo UI: https://komodo.in.hypyr.space"
log "  - Caddy Proxy: Running and serving TLS certificates"
log ""
log "Next steps:"
log "  1. Access Komodo UI to configure additional stacks"
log "  2. Deploy platform tier services via Komodo"
log "  3. Verify TLS certificates are being issued correctly"
log ""
log "Service status:"
docker stack ls
docker service ls --filter "label=com.docker.stack.namespace=op-connect"
docker service ls --filter "label=com.docker.stack.namespace=komodo"
docker service ls --filter "label=com.docker.stack.namespace=caddy"

exit 0
