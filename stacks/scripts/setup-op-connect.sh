#!/usr/bin/env bash
# Quick setup script for 1Password Connect on TrueNAS
# Run this from your workstation (Mac) where op CLI is authenticated

set -euo pipefail

TRUENAS_HOST="${TRUENAS_HOST:-truenas}"
VAULT_NAME="${VAULT_NAME:-homelab}"
SERVER_NAME="${SERVER_NAME:-homelab-truenas}"

echo "==> 1Password Connect Setup for TrueNAS"
echo ""

# Step 1: Generate Connect server credentials
echo "Step 1: Generating Connect server credentials..."
echo "  Server: $SERVER_NAME"
echo "  Vault: $VAULT_NAME"
echo ""

if ! op vault get "$VAULT_NAME" &>/dev/null; then
  echo "❌ Error: Vault '$VAULT_NAME' not found or not accessible"
  echo "   Available vaults:"
  op vault list
  exit 1
fi

# Check if server already exists
if op connect server get "$SERVER_NAME" &>/dev/null 2>&1; then
  echo "⚠️  Connect server '$SERVER_NAME' already exists"
  read -p "Do you want to create a new one? (y/N) " -n 1 -r REPLY
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Using existing server. You'll need to locate the credentials file manually."
    exit 0
  fi
fi

# Create the server and save credentials
echo "Creating Connect server..."
CREDS_FILE="./1password-credentials-$(date +%Y%m%d-%H%M%S).json"

if ! op connect server create "$SERVER_NAME" --vaults "$VAULT_NAME" > "$CREDS_FILE"; then
  echo "❌ Failed to create Connect server"
  exit 1
fi

echo "✅ Credentials saved to: $CREDS_FILE"
echo ""

# Step 2: Copy to TrueNAS
echo "Step 2: Copying credentials to TrueNAS..."
echo "  Target: $TRUENAS_HOST:/mnt/apps01/secrets/op/1password-credentials.json"
echo ""

if ! ssh "$TRUENAS_HOST" "mkdir -p /mnt/apps01/secrets/op" 2>/dev/null; then
  echo "❌ Failed to create directory on TrueNAS"
  echo "   Ensure you can SSH to $TRUENAS_HOST"
  exit 1
fi

if ! scp "$CREDS_FILE" "$TRUENAS_HOST:/mnt/apps01/secrets/op/1password-credentials.json"; then
  echo "❌ Failed to copy credentials to TrueNAS"
  exit 1
fi

if ! ssh "$TRUENAS_HOST" "chmod 600 /mnt/apps01/secrets/op/1password-credentials.json"; then
  echo "⚠️  Warning: Failed to set permissions on credentials file"
fi

echo "✅ Credentials copied to TrueNAS"
echo ""

# Step 3: Generate shared Connect token
echo "Step 3: Creating shared Connect token..."
echo ""

TOKEN_FILE="./connect-token-$(date +%Y%m%d-%H%M%S).txt"
echo "Creating one token for all stacks to share..."

if ! op connect token create "homelab-stacks" --server "$SERVER_NAME" --vault "$VAULT_NAME" > "$TOKEN_FILE"; then
  echo "❌ Failed to create Connect token"
  exit 1
fi

echo "✅ Token saved to: $TOKEN_FILE"
echo ""

# Step 4: Store as Docker Swarm secret
echo "Step 4: Storing token as Docker Swarm secret..."
echo ""

TOKEN_VALUE=$(cat "$TOKEN_FILE")

if ssh "$TRUENAS_HOST" "docker secret ls | grep -q op_connect_token" 2>/dev/null; then
  echo "⚠️  Swarm secret 'op_connect_token' already exists"
  read -p "Remove and recreate? (y/N) " -n 1 -r REPLY
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh "$TRUENAS_HOST" "docker secret rm op_connect_token" || true
  else
    echo "Skipping secret creation."
    TOKEN_CREATED=false
  fi
fi

if [[ ${TOKEN_CREATED:-true} != false ]]; then
  if echo "$TOKEN_VALUE" | ssh "$TRUENAS_HOST" "docker secret create op_connect_token -"; then
    echo "✅ Token stored as Swarm secret: op_connect_token"
  else
    echo "❌ Failed to create Swarm secret"
    echo "   You can create it manually:"
    echo "   cat $TOKEN_FILE | ssh $TRUENAS_HOST 'docker secret create op_connect_token -'"
  fi
fi

echo ""
echo "==> Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Deploy op-connect stack in Komodo:"
echo "   - Point to: stacks/platform/secrets/op-connect"
echo "   - No additional config needed (credentials already on host)"
echo ""
echo "2. Verify deployment:"
echo "   ssh $TRUENAS_HOST 'docker service ls | grep op-connect'"
echo "   ssh $TRUENAS_HOST 'curl http://localhost:8080/health'"
echo ""
echo "3. Add Connect tokens to your stacks in Komodo secrets UI"
echo "   (See generated *-token-*.txt files)"
echo ""
echo "4. Restructure 1Password items (see stacks/docs/OP_CONNECT_MIGRATION.md)"
echo ""
echo "📄 Documentation:"
echo "   - stacks/platform/secrets/op-connect/README.md"
echo "   - stacks/docs/OP_CONNECT_MIGRATION.md"
echo ""

# Cleanup prompt
echo "⚠️  Security Note:"
echo "The credentials file contains full vault access. Keep it secure!"
echo "Local copy: $CREDS_FILE"
echo ""
read -p "Delete local credentials file? (Y/n) " -n 1 -r REPLY
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  rm -f "$CREDS_FILE"
  echo "✅ Local credentials deleted (still on TrueNAS at /mnt/apps01/secrets/op/)"
fi
