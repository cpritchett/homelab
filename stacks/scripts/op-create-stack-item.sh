#!/usr/bin/env bash
set -euo pipefail

# op-create-stack-item.sh
# Create 1Password items from .env.example files for use with op-export-stack-env.sh
#
# Usage:
#   ./op-create-stack-item.sh <path-to-env-example-file>
#
# Examples:
#   ./op-create-stack-item.sh ../platform/backups/restic/restic.env.example
#   ./op-create-stack-item.sh ../platform/auth/authentik/authentik.env.example
#   ./op-create-stack-item.sh ../platform/auth/authentik/postgres.env.example
#
# This script:
# 1. Parses variable names from .env.example
# 2. Prompts for real values (or uses existing values if they're not example/placeholder)
# 3. Creates a 1Password item with appropriate tags and fields
# 4. Tags it for use with op-export-stack-env.sh

VAULT="${VAULT:-homelab}"
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

usage() {
  cat <<EOF
Usage: $0 <path-to-env-example-file>

Create a 1Password item from a <item-name>.env.example file for stack secret management.

Arguments:
  path-to-env-example-file    Path to the env example file (e.g., restic.env.example)
                              The filename determines the 1Password item name

Environment:
  VAULT                       1Password vault name (default: homelab)

Examples:
  # Create item for restic stack
  $0 ../platform/backups/restic/restic.env.example

  # Create multiple items for authentik stack
  $0 ../platform/auth/authentik/authentik.env.example
  $0 ../platform/auth/authentik/postgres.env.example
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

ENV_EXAMPLE_PATH="$1"
ITEM_TITLE="${2:-}"

# Validate input file
if [[ ! -f "$ENV_EXAMPLE_PATH" ]]; then
  echo -e "${COLOR_RED}Error: file not found: $ENV_EXAMPLE_PATH${COLOR_RESET}" >&2
  exit 1
fi

# Derive stack name from path (e.g., stacks/platform/backups/restic/.env.example -> restic)
# Supports both absolute and relative paths
STACK_NAME=""
if [[ "$ENV_EXAMPLE_PATH" =~ stacks/([^/]+/)?([^/]+)/[^/]+$ ]]; then
  STACK_NAME="${BASH_REMATCH[2]}"
elif [[ "$ENV_EXAMPLE_PATH" =~ /([^/]+)/\.env\.example$ ]]; then
  STACK_NAME="${BASH_REMATCH[1]}"
else
  # Fallback: use parent directory name
  STACK_NAME="$(basename "$(dirname "$ENV_EXAMPLE_PATH")")"
fi

# If no explicit title provided, derive from filename
if [[ -z "$ITEM_TITLE" ]]; then
  ITEM_TITLE="$(basename "$ENV_EXAMPLE_PATH" .example)"
  # If it's just ".env", use a more descriptive name
  [[ "$ITEM_TITLE" == ".env" ]] && ITEM_TITLE="${STACK_NAME}.env"
fi

TAG="stack:${STACK_NAME}"

echo -e "${COLOR_BLUE}==> Creating 1Password item${COLOR_RESET}"
echo -e "    File:  $ENV_EXAMPLE_PATH"
echo -e "    Stack: $STACK_NAME"
echo -e "    Item:  $ITEM_TITLE"
echo -e "    Tag:   $TAG"
echo -e "    Vault: $VAULT"
echo ""

# Verify vault access
if ! op vault get "$VAULT" >/dev/null 2>&1; then
  echo -e "${COLOR_RED}Error: cannot access vault '$VAULT'${COLOR_RESET}" >&2
  echo "Make sure you're signed in: op signin" >&2
  exit 1
fi

# Check if item already exists
if op item get "$ITEM_TITLE" --vault "$VAULT" >/dev/null 2>&1; then
  echo -e "${COLOR_YELLOW}Warning: item '$ITEM_TITLE' already exists in vault '$VAULT'${COLOR_RESET}"
  echo ""
  echo "Options:"
  echo "  1) Update with new values from $ENV_EXAMPLE_PATH"
  echo "  2) Skip (use existing item as-is)"
  echo "  3) Cancel"
  read -rp "Choose (1-3): " -n 1 choice
  echo
  
  case "$choice" in
    1)
      UPDATE_MODE=true
      echo "✓ Will update existing item"
      ;;
    2)
      echo "✓ Skipping. Using existing item."
      echo ""
      echo "Note: To export the existing item to filesystem:"
      echo "  ./op-export-stack-env.sh $STACK_NAME"
      exit 0
      ;;
    3)
      echo "Cancelled."
      exit 0
      ;;
    *)
      echo -e "${COLOR_RED}Invalid choice. Aborting.${COLOR_RESET}" >&2
      exit 1
      ;;
  esac
else
  UPDATE_MODE=false
fi

# Parse .env.example and collect variables
declare -A VARS
declare -a VAR_ORDER

echo -e "${COLOR_BLUE}==> Parsing $ENV_EXAMPLE_PATH${COLOR_RESET}"

while IFS= read -r line; do
  # Skip comments and empty lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  
  # Match VAR=value or VAR=
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    var_name="${BASH_REMATCH[1]}"
    var_value="${BASH_REMATCH[2]}"
    
    # Store variable and maintain order
    VARS["$var_name"]="$var_value"
    VAR_ORDER+=("$var_name")
  fi
done < "$ENV_EXAMPLE_PATH"

if [[ ${#VAR_ORDER[@]} -eq 0 ]]; then
  echo -e "${COLOR_RED}Error: no variables found in $ENV_EXAMPLE_PATH${COLOR_RESET}" >&2
  exit 1
fi

echo -e "${COLOR_GREEN}Found ${#VAR_ORDER[@]} variables${COLOR_RESET}"
echo ""

# Collect values from user
declare -A FINAL_VARS

echo -e "${COLOR_BLUE}==> Enter values for each variable${COLOR_RESET}"
echo "Press Enter to use the example value, or provide a new value."
echo "For empty values, type '(empty)' explicitly."
echo ""

is_placeholder() {
  local value="$1"
  # Detect common placeholder patterns
  [[ "$value" =~ ^your- ]] && return 0
  [[ "$value" =~ example\.com$ ]] && return 0
  [[ "$value" =~ ^s3:https://s3\.example\.com ]] && return 0
  [[ "$value" == "your-secure-password" ]] && return 0
  [[ "$value" == "your-access-key" ]] && return 0
  [[ "$value" == "your-secret-key" ]] && return 0
  [[ -z "$value" ]] && return 0
  return 1
}

for var_name in "${VAR_ORDER[@]}"; do
  example_value="${VARS[$var_name]}"
  
  # Check if it's obviously a placeholder
  if is_placeholder "$example_value"; then
    prompt_default=""
    prompt_text="${COLOR_YELLOW}$var_name${COLOR_RESET} [required]: "
  else
    prompt_default="$example_value"
    prompt_text="${COLOR_YELLOW}$var_name${COLOR_RESET} [$example_value]: "
  fi
  
  read -rp "$(echo -e "$prompt_text")" user_input
  
  if [[ -z "$user_input" ]]; then
    if [[ -z "$prompt_default" ]]; then
      echo -e "${COLOR_RED}  Error: value required for $var_name${COLOR_RESET}" >&2
      exit 1
    fi
    FINAL_VARS["$var_name"]="$prompt_default"
  elif [[ "$user_input" == "(empty)" ]]; then
    FINAL_VARS["$var_name"]=""
  else
    FINAL_VARS["$var_name"]="$user_input"
  fi
done

echo ""
echo -e "${COLOR_BLUE}==> Review values before committing${COLOR_RESET}"
echo ""
for var_name in "${VAR_ORDER[@]}"; do
  var_value="${FINAL_VARS[$var_name]}"
  if [[ -z "$var_value" ]]; then
    echo "  $var_name = (empty)"
  elif [[ ${#var_value} -gt 50 ]]; then
    # Truncate long values for display
    echo "  $var_name = ${var_value:0:47}..."
  else
    echo "  $var_name = $var_value"
  fi
done

echo ""
read -rp "Confirm and $([ "$UPDATE_MODE" = "true" ] && echo "update" || echo "create") item? (y/N) " -n 1 confirm
echo

if [[ ! $confirm =~ ^[Yy]$ ]]; then
  echo "Cancelled. No changes made."
  exit 0
fi

if [[ "$UPDATE_MODE" == "true" ]]; then
  echo -e "${COLOR_BLUE}==> Updating 1Password item '$ITEM_TITLE'${COLOR_RESET}"

  # Get current item values for comparison
  CURRENT_ITEM="$(op item get "$ITEM_TITLE" --vault "$VAULT" --format=json)" || {
    echo -e "${COLOR_RED}Error: failed to fetch current item for comparison${COLOR_RESET}" >&2
    exit 1
  }

  UPDATED_COUNT=0
  ERRORS=0

  for var_name in "${VAR_ORDER[@]}"; do
    var_value="${FINAL_VARS[$var_name]}"
    current_value="$(echo "$CURRENT_ITEM" | jq -r ".fields[] | select(.label == \"$var_name\") | .value" 2>/dev/null || echo "")"
    
    if [[ "$current_value" == "$var_value" ]]; then
      # Value unchanged
      continue
    fi
    
    # Value changed - update it
    if op item edit "$ITEM_TITLE" --vault "$VAULT" "$var_name=$var_value" </dev/null >/dev/null 2>&1; then
      if [[ -n "$current_value" && "$current_value" != "$var_value" ]]; then
        echo -e "  ✓ Updated: $var_name (was out of date)"
      else
        echo -e "  ✓ Set: $var_name"
      fi
      UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
      echo -e "${COLOR_RED}  Error: failed to update $var_name${COLOR_RESET}" >&2
      ERRORS=$((ERRORS + 1))
    fi
  done

  # Ensure tag is set
  if op item edit "$ITEM_TITLE" --vault "$VAULT" --tags "$TAG" </dev/null >/dev/null 2>&1; then
    : # Tag set successfully
  else
    echo -e "${COLOR_YELLOW}  Warning: could not update tags${COLOR_RESET}"
  fi

  if [[ $ERRORS -gt 0 ]]; then
    echo -e "${COLOR_RED}❌ Updated item with $ERRORS error(s)${COLOR_RESET}" >&2
    exit 1
  elif [[ $UPDATED_COUNT -eq 0 ]]; then
    echo -e "${COLOR_YELLOW}⊘ No changes needed (all values already current)${COLOR_RESET}"
  else
    echo -e "${COLOR_GREEN}✓ Updated item '$ITEM_TITLE' ($UPDATED_COUNT field(s))${COLOR_RESET}"
  fi
else
  echo -e "${COLOR_BLUE}==> Creating 1Password item '$ITEM_TITLE'${COLOR_RESET}"
  
  # Create new item
  # Build field arguments (for Secure Note items, no field type specifier needed)
  FIELD_ARGS=()
  for var_name in "${VAR_ORDER[@]}"; do
    var_value="${FINAL_VARS[$var_name]}"
    FIELD_ARGS+=("${var_name}=${var_value}")
  done
  
  # Create the item with stdin redirected from /dev/null
  if op item create \
    --category="Secure Note" \
    --title="$ITEM_TITLE" \
    --vault="$VAULT" \
    --tags="$TAG" \
    "${FIELD_ARGS[@]}" </dev/null >/dev/null 2>&1; then
    echo -e "${COLOR_GREEN}✓ Created item '$ITEM_TITLE'${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}Error: failed to create item${COLOR_RESET}" >&2
    echo ""
    echo "Possible causes:"
    echo "  • Vault '$VAULT' is not accessible"
    echo "  • Item title '$ITEM_TITLE' is invalid"
    echo "  • 1Password CLI is not authenticated"
    echo ""
    echo "Trying again with error details..."
    op item create \
      --category="Secure Note" \
      --title="$ITEM_TITLE" \
      --vault="$VAULT" \
      --tags="$TAG" \
      "${FIELD_ARGS[@]}" </dev/null >&2
    exit 1
  fi
fi

echo ""
echo -e "${COLOR_GREEN}==> Success!${COLOR_RESET}"
echo ""
echo "The item '$ITEM_TITLE' is now available in vault '$VAULT' with tag '$TAG'."
echo ""
echo "To export this to the host, run op-export-stack-env.sh:"
echo "  ./op-export-stack-env.sh $STACK_NAME"
echo ""
echo "Or deploy via Komodo using the op-export stack with STACKS=\"$STACK_NAME\""
