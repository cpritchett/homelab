#!/usr/bin/env bash
set -euo pipefail

VAULT="${VAULT:-homelab}"
DEST_ROOT="${DEST_ROOT:-/mnt/apps01/secrets}"

STACK="${1:-}"
if [[ -z "$STACK" ]]; then
  echo "Usage: $0 <stack-name>" >&2
  exit 2
fi

TAG="stack:${STACK}"
DEST_DIR="${DEST_ROOT}/${STACK}"
mkdir -p "$DEST_DIR"

# Verify vault access
if ! op vault get "$VAULT" >/dev/null 2>&1; then
  echo "Error: cannot access vault '$VAULT'" >&2
  exit 1
fi

echo "Exporting secrets for stack: $STACK from vault: $VAULT"

ITEM_COUNT=0
while read -r ITEM_ID; do
  ITEM_JSON="$(op item get "$ITEM_ID" --vault "$VAULT" --format=json)" || {
    echo "Error: failed to fetch item '$ITEM_ID' from vault '$VAULT'" >&2
    continue
  }

  if ! echo "$ITEM_JSON" | jq -e . >/dev/null 2>&1; then
    echo "Warning: invalid JSON for item '$ITEM_ID'; skipping" >&2
    continue
  fi

  TITLE="$(echo "$ITEM_JSON" | jq -er '.title')" || {
    echo "Warning: missing or invalid title for item '$ITEM_ID'; skipping" >&2
    continue
  }
  OUT="${DEST_DIR}/${TITLE}"

  if ! echo "$ITEM_JSON" | jq -r '
    .fields[]?
    | select(.label? and (.value? != null))
    | "\(.label)=\(.value)"
  ' > "$OUT"; then
    echo "Error: failed to render env file for item '$ITEM_ID' ('$TITLE')" >&2
    rm -f "$OUT"
    continue
  fi

  if [[ ! -s "$OUT" ]]; then
    echo "Warning: generated env file '$OUT' is empty; removing" >&2
    rm -f "$OUT"
    continue
  fi

  echo "  ✓ Exported: $TITLE"
  ITEM_COUNT=$((ITEM_COUNT + 1))
done < <(op item list --vault "$VAULT" --format=json |
  jq -r --arg tag "$TAG" '
    .[]
    | select((.title | endswith(".env")) and ((.tags // []) | index($tag)))
    | .id
  ')

if [[ $ITEM_COUNT -eq 0 ]]; then
  echo "Warning: no items found for stack '$STACK' with tag '$TAG'" >&2
  exit 0
fi

echo "Successfully exported $ITEM_COUNT secret file(s) for stack: $STACK"
