#!/usr/bin/env bash
set -euo pipefail

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

VAULT="${VAULT:-homelab}"
DEST_ROOT="${DEST_ROOT:-/mnt/apps01/secrets}"

STACK="${1:-}"
if [[ -z "$STACK" ]]; then
  echo "Usage: $0 <stack-name>" >&2
  echo ""
  echo "Environment variables:"
  echo "  VAULT      1Password vault name (default: homelab)"
  echo "  DEST_ROOT  Destination directory (default: /mnt/apps01/secrets)"
  echo ""
  echo "Example:"
  echo "  $0 authentik"
  exit 2
fi

TAG="stack:${STACK}"
DEST_DIR="${DEST_ROOT}/${STACK}"

# Verify vault access
if ! op vault get "$VAULT" >/dev/null 2>&1; then
  echo -e "${COLOR_RED}Error: cannot access vault '$VAULT'${COLOR_RESET}" >&2
  echo ""
  echo "Possible causes:"
  echo "  • Vault name is incorrect"
  echo "  • 1Password CLI is not authenticated"
  echo "  • Service account token is invalid (if using OP_SERVICE_ACCOUNT_TOKEN)"
  echo ""
  echo "To sign in:"
  echo "  op signin"
  exit 1
fi

# Create destination directory
if ! mkdir -p "$DEST_DIR" 2>/dev/null; then
  echo -e "${COLOR_RED}Error: cannot create directory: $DEST_DIR${COLOR_RESET}" >&2
  echo "Check permissions on: $(dirname "$DEST_DIR")"
  exit 1
fi

echo -e "${COLOR_BLUE}==> Exporting secrets for stack: $STACK${COLOR_RESET}"
echo "    Vault: $VAULT"
echo "    Destination: $DEST_DIR"
echo ""

ITEM_COUNT=0
EXPORT_ERROR=0
NEW_FILES=0
UPDATED_FILES=0
SKIPPED_FILES=0

# Validate that ITEM_JSON is non-empty before processing
validate_json() {
  local json="$1"
  local item_id="$2"
  
  if [[ -z "$json" ]]; then
    echo -e "${COLOR_YELLOW}Warning: empty response for item '$item_id'; skipping${COLOR_RESET}" >&2
    return 1
  fi
  
  if ! echo "$json" | jq -e . >/dev/null 2>&1; then
    echo -e "${COLOR_YELLOW}Warning: invalid JSON for item '$item_id'; skipping${COLOR_RESET}" >&2
    return 1
  fi
  
  return 0
}

while read -r ITEM_ID; do
  [[ -z "$ITEM_ID" ]] && continue
  
  ITEM_JSON="$(op item get "$ITEM_ID" --vault "$VAULT" --format=json)" || {
    echo -e "${COLOR_RED}Error: failed to fetch item '$ITEM_ID' from vault '$VAULT'${COLOR_RESET}" >&2
    EXPORT_ERROR=$((EXPORT_ERROR + 1))
    continue
  }

  if ! validate_json "$ITEM_JSON" "$ITEM_ID"; then
    EXPORT_ERROR=$((EXPORT_ERROR + 1))
    continue
  fi

  TITLE="$(echo "$ITEM_JSON" | jq -er '.title')" || {
    echo -e "${COLOR_YELLOW}Warning: missing or invalid title for item '$ITEM_ID'; skipping${COLOR_RESET}" >&2
    EXPORT_ERROR=$((EXPORT_ERROR + 1))
    continue
  }
  OUT="${DEST_DIR}/${TITLE}"

  # Check if file already exists
  if [[ -f "$OUT" ]]; then
    EXISTING_HASH="$(sha256sum "$OUT" | awk '{print $1}')"
    TEMP_FILE="${OUT}.tmp.$$"
  else
    EXISTING_HASH=""
    TEMP_FILE="$OUT"
  fi

  # Render to temp file first
  if ! echo "$ITEM_JSON" | jq -r '
    .fields[]?
    | select(.label? and (.value? != null))
    | "\(.label)=\(.value)"
  ' > "$TEMP_FILE"; then
    echo -e "${COLOR_RED}Error: failed to render env file for item '$ITEM_ID' ('$TITLE')${COLOR_RESET}" >&2
    rm -f "$TEMP_FILE"
    EXPORT_ERROR=$((EXPORT_ERROR + 1))
    continue
  fi

  if [[ ! -s "$TEMP_FILE" ]]; then
    echo -e "${COLOR_YELLOW}Warning: generated env file '$OUT' is empty; skipping${COLOR_RESET}" >&2
    rm -f "$TEMP_FILE"
    EXPORT_ERROR=$((EXPORT_ERROR + 1))
    continue
  fi

  # Compare with existing file if present
  if [[ -n "$EXISTING_HASH" ]]; then
    NEW_HASH="$(sha256sum "$TEMP_FILE" | awk '{print $1}')"
    if [[ "$EXISTING_HASH" == "$NEW_HASH" ]]; then
      rm -f "$TEMP_FILE"
      SKIPPED_FILES=$((SKIPPED_FILES + 1))
      echo -e "  ⊘ No changes: $TITLE (up to date)"
      ITEM_COUNT=$((ITEM_COUNT + 1))
      continue
    else
      mv "$TEMP_FILE" "$OUT"
      UPDATED_FILES=$((UPDATED_FILES + 1))
      echo -e "  ✓ Updated: $TITLE"
    fi
  else
    mv "$TEMP_FILE" "$OUT"
    NEW_FILES=$((NEW_FILES + 1))
    echo -e "  ✓ Exported: $TITLE"
  fi
  
  ITEM_COUNT=$((ITEM_COUNT + 1))
done < <(ITEMS_JSON="$(op item list --vault "$VAULT" --format=json)" || {
  echo -e "${COLOR_RED}Error: failed to list items in vault '$VAULT'${COLOR_RESET}" >&2
  exit 1
}

if ! echo "$ITEMS_JSON" | jq -e . >/dev/null 2>&1; then
  echo "Error: invalid JSON response from 'op item list'" >&2
  exit 1
fi

echo "$ITEMS_JSON" |
  jq -r --arg tag "$TAG" '
    .[]
    | select((.title | endswith(".env")) and ((.tags // []) | index($tag)))
    | .id
  ')

if [[ $ITEM_COUNT -eq 0 ]]; then
  echo ""
  echo -e "${COLOR_YELLOW}⚠️  No items found for stack '$STACK' with tag '$TAG'${COLOR_RESET}"
  echo "   Make sure:"
  echo "     1. Items are named: *.env (e.g., 'restic.env', 'authentik.env')"
  echo "     2. Items are tagged: $TAG"
  echo "     3. Items exist in vault: $VAULT"
  echo ""
  [[ $EXPORT_ERROR -gt 0 ]] && exit 1
  exit 0
fi

# Count newly exported files
# NEW_COUNT will be calculated from counters

echo ""
echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
echo -e "Export Summary for Stack: ${COLOR_BLUE}$STACK${COLOR_RESET}"
echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"

if [[ $NEW_FILES -gt 0 ]]; then
  echo -e "  ${COLOR_GREEN}✓ New exports:${COLOR_RESET}   $NEW_FILES"
fi

if [[ $UPDATED_FILES -gt 0 ]]; then
  echo -e "  ${COLOR_GREEN}✓ Updated:${COLOR_RESET}       $UPDATED_FILES"
fi

if [[ $SKIPPED_FILES -gt 0 ]]; then
  echo -e "  ${COLOR_YELLOW}⊘ Unchanged:${COLOR_RESET}     $SKIPPED_FILES"
fi

if [[ $EXPORT_ERROR -gt 0 ]]; then
  echo -e "  ${COLOR_RED}✗ Failed:${COLOR_RESET}        $EXPORT_ERROR"
  echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_RED}❌ Export failed. Check error messages above for details.${COLOR_RESET}"
  echo ""
  exit 1
fi

echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
echo ""
echo -e "${COLOR_GREEN}✅ Successfully exported $ITEM_COUNT secret file(s) for stack: $STACK${COLOR_RESET}"
echo -e "   Destination: ${COLOR_BLUE}$DEST_ROOT/$STACK/${COLOR_RESET}"
echo ""
