#!/bin/bash
###############################################################################
# Create Docker Swarm Secrets (One-Time Setup)
#
# Run this ONCE before the first bootstrap to create required Swarm secrets.
# This script should be run manually, not automatically.
###############################################################################

set -euo pipefail

SECRETS_PATH="${SECRETS_PATH:-/mnt/apps01/secrets}"

echo "========================================="
echo "Creating Docker Swarm Secrets"
echo "========================================="
echo ""
echo "This script creates Swarm secrets from:"
echo "  1. Files in ${SECRETS_PATH}"
echo "  2. 1Password via op CLI (if available)"
echo ""
echo "Prerequisites:"
echo "  - Docker Swarm must be initialized"
echo "  - Secret files must exist OR op CLI must be configured"
echo ""

# Verify Swarm is active
if ! docker info | grep -q "Swarm: active"; then
    echo "ERROR: Docker Swarm is not active"
    echo "Initialize with: docker swarm init --advertise-addr \$(hostname -I | awk '{print \$1}')"
    exit 1
fi

echo "✓ Docker Swarm is active"
echo ""

# Function to create secret
create_secret() {
    local secret_name=$1
    local secret_file=$2
    local op_reference=$3

    if docker secret inspect "$secret_name" >/dev/null 2>&1; then
        echo "⚠ Secret already exists: $secret_name (skipping)"
        return 0
    fi

    echo "Creating secret: $secret_name"

    # Try file first
    if [ -n "$secret_file" ] && [ -f "$secret_file" ]; then
        cat "$secret_file" | docker secret create "$secret_name" -
        echo "✓ Created $secret_name from file: $secret_file"
        return 0
    fi

    # Try 1Password
    if [ -n "$op_reference" ] && command -v op >/dev/null 2>&1; then
        if op read "$op_reference" 2>/dev/null | docker secret create "$secret_name" - 2>/dev/null; then
            echo "✓ Created $secret_name from 1Password: $op_reference"
            return 0
        fi
    fi

    echo "✗ FAILED to create $secret_name"
    echo "  Tried: file=$secret_file, op=$op_reference"
    return 1
}

echo "Creating secrets..."
echo ""

# op_connect_token
create_secret "op_connect_token" \
    "${SECRETS_PATH}/op/connect-token" \
    ""

# CLOUDFLARE_API_TOKEN
create_secret "CLOUDFLARE_API_TOKEN" \
    "${SECRETS_PATH}/cloudflare/api-token" \
    ""

# komodo_db_password
create_secret "komodo_db_password" \
    "" \
    "op://homelab/Komodo - Barbary/Database"

# komodo_passkey
create_secret "komodo_passkey" \
    "" \
    "op://homelab/Komodo - Barbary/credential"

echo ""
echo "========================================="
echo "Secret Creation Summary"
echo "========================================="
docker secret ls

echo ""
echo "Next steps:"
echo "  1. Verify all required secrets exist above"
echo "  2. Run bootstrap: /mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh"
echo ""
