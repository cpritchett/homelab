#!/bin/bash
set -e

REPO_DIR="/mnt/apps01/repos/homelab"
STACKS_DIR="${REPO_DIR}/stacks"

echo "=== Homelab Stack Deployment ==="
echo "Started at: $(date)"

# Deploy infrastructure first (no dependencies)
echo ""
echo "--- Deploying infrastructure ---"

echo "Deploying komodo stack..."
docker stack deploy -c ${STACKS_DIR}/infrastructure/komodo-compose.yaml komodo || echo "Komodo deploy failed (may already exist)"

echo "Waiting for komodo to be ready..."
sleep 30

echo "Deploying caddy stack..."
docker stack deploy -c ${STACKS_DIR}/infrastructure/caddy-compose.yaml caddy || echo "Caddy deploy failed (may already exist)"

echo "Waiting for caddy to be ready..."
sleep 30

# Deploy platform stacks
echo ""
echo "--- Deploying platform stacks ---"

STACKS=(
    "authentik:stacks/platform/auth/authentik/compose.yaml"
    "forgejo:stacks/platform/cicd/forgejo/compose.yaml"
    "woodpecker:stacks/platform/cicd/woodpecker/compose.yaml"
    "restic:stacks/platform/backups/restic/compose.yaml"
)

for stack in "${STACKS[@]}"; do
    IFS=':' read -r name compose_path <<< "$stack"
    echo "Deploying ${name}..."
    docker stack deploy -c "${REPO_DIR}/${compose_path}" ${name} || echo "${name} deploy failed"
    echo "Waiting for ${name}..."
    sleep 15
done

echo ""
echo "=== Deployment Complete ==="
echo "Finished at: $(date)"

# Show stack status
echo ""
echo "--- Stack Status ---"
docker stack ps --format "table {{.Name}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}" | head -20
