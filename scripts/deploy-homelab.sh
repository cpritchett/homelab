#!/bin/bash
set -e

REPO_DIR="/mnt/apps01/repos/homelab"
STACKS_DIR="${REPO_DIR}/stacks"

echo "=== Homelab Stack Deployment ==="
echo "Started at: $(date)"

# Deploy infrastructure first (no dependencies)
echo ""
echo "--- Deploying infrastructure ---"

echo "Deploying op-connect stack (required by komodo and others)..."
docker stack deploy -c ${STACKS_DIR}/infrastructure/op-connect-compose.yaml op-connect || echo "op-connect deploy failed (may already exist)"

echo "Waiting for op-connect to be ready..."
sleep 30

echo "Deploying step-ca stack..."
docker stack deploy -c ${STACKS_DIR}/infrastructure/step-ca-compose.yaml step-ca || echo "step-ca deploy failed (may already exist)"

echo "Waiting for step-ca to be ready..."
sleep 45

echo "Deploying komodo stack..."
docker stack deploy -c ${STACKS_DIR}/infrastructure/komodo-compose.yaml komodo || echo "Komodo deploy failed (may already exist)"

echo "Waiting for komodo to be ready..."
sleep 30

echo "Deploying caddy stack..."
docker stack deploy -c ${STACKS_DIR}/infrastructure/caddy-compose.yaml caddy || echo "Caddy deploy failed (may already exist)"

echo "Waiting for caddy to be ready..."
sleep 30

# Platform and application stacks are managed by Komodo (ADR-0022).
# Use Komodo UI or `km execute deploy-stack <name>` to deploy them.

echo ""
echo "=== Infrastructure Deployment Complete ==="
echo "Finished at: $(date)"

# Show stack status
echo ""
echo "--- Stack Status ---"
docker stack ps --format "table {{.Name}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}" | head -20
