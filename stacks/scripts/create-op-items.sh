#!/usr/bin/env bash
set -euo pipefail

VAULT="homelab"

# Helper to generate a password
gen_pw() {
  openssl rand -base64 32 | tr -d '/+=' | head -c 32
}

echo "Creating 1Password items for Docker stacks..."
echo ""

# Authentik
echo "Creating authentik-stack item..."
op item create \
  --vault="$VAULT" \
  --category=password \
  --title="authentik-stack" \
  "secret_key[password]=$(gen_pw)" \
  "bootstrap_email[email]=admin@hypyr.space" \
  "bootstrap_password[password]=$(gen_pw)" \
  "postgres_password[password]=$(gen_pw)"

# Restic
if ! op item get restic --vault="$VAULT" >/dev/null 2>&1; then
  echo "Creating restic item..."
  op item create \
    --vault="$VAULT" \
    --category=password \
    --title="restic" \
    "repository[text]=s3:https://seaweedfs.in.hypyr.space:8333/restic" \
    "password[password]=$(gen_pw)" \
    "aws_access_key_id[text]=restic" \
    "aws_secret_access_key[password]=$(gen_pw)" \
    "aws_endpoint[text]=https://seaweedfs.in.hypyr.space:8333" \
    "aws_default_region[text]=us-east-1"
else
  echo "Restic item already exists, skipping..."
fi

# Forgejo
echo "Checking forgejo item..."
if op item get forgejo --vault="$VAULT" >/dev/null 2>&1; then
  if ! op item get forgejo --vault="$VAULT" --fields postgres_password >/dev/null 2>&1; then
    echo "Adding postgres_password to forgejo..."
    op item edit forgejo --vault="$VAULT" "postgres_password[password]=$(gen_pw)"
  else
    echo "Forgejo already has postgres_password, skipping..."
  fi
else
  echo "Creating forgejo item..."
  op item create \
    --vault="$VAULT" \
    --category=password \
    --title="forgejo" \
    "postgres_password[password]=$(gen_pw)"
fi

# Woodpecker
echo "Checking woodpecker item..."
if op item get woodpecker --vault="$VAULT" >/dev/null 2>&1; then
  if ! op item get woodpecker --vault="$VAULT" --fields agent_secret >/dev/null 2>&1; then
    echo "Adding agent_secret to woodpecker..."
    op item edit woodpecker --vault="$VAULT" "agent_secret[password]=$(gen_pw)"
  fi
  if ! op item get woodpecker --vault="$VAULT" --fields gitea_secret >/dev/null 2>&1; then
    echo "Adding gitea_secret to woodpecker..."
    op item edit woodpecker --vault="$VAULT" "gitea_secret[password]=$(gen_pw)"
  fi
  if ! op item get woodpecker --vault="$VAULT" --fields admin_username >/dev/null 2>&1; then
    echo "Adding admin_username to woodpecker..."
    op item edit woodpecker --vault="$VAULT" "admin_username[text]=admin"
  fi
  if ! op item get woodpecker --vault="$VAULT" --fields gitea_client >/dev/null 2>&1; then
    echo "Adding gitea_client placeholder to woodpecker..."
    op item edit woodpecker --vault="$VAULT" "gitea_client[text]=FILL_ME_IN"
  fi
else
  echo "Creating woodpecker item..."
  op item create \
    --vault="$VAULT" \
    --category=password \
    --title="woodpecker" \
    "agent_secret[password]=$(gen_pw)" \
    "gitea_client[text]=FILL_ME_IN" \
    "gitea_secret[password]=$(gen_pw)" \
    "admin_username[text]=admin"
fi

# Cloudflare-stacks check
echo ""
echo "Verifying cloudflare-stacks item..."
if ! op item get cloudflare-stacks --vault="$VAULT" >/dev/null 2>&1; then
  echo "Creating cloudflare-stacks item..."
  echo "⚠️  You need to provide your Cloudflare API token"
  read -p "Enter Cloudflare API Token: " -s CF_TOKEN
  echo ""
  op item create \
    --vault="$VAULT" \
    --category=password \
    --title="cloudflare-stacks" \
    --tags="stacks" \
    "api_token[password]=$CF_TOKEN"
  echo "✅ Created cloudflare-stacks"
else
  echo "✓ cloudflare-stacks exists"
fi

echo ""
echo "✅ Done!"
echo ""
echo "Manual steps:"
echo "  1. Update woodpecker.gitea_client with OAuth client ID from Forgejo"
echo ""
echo "Test with: cd stacks/platform/auth/authentik && op inject -i env.template -o test.env"
