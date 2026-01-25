#!/usr/bin/env bash
set -euo pipefail

VAULT="${VAULT:-homelab}"
DEST_ROOT="${DEST_ROOT:-/mnt/apps01/secrets}"

STACK="${1:-}"
if [[ -z "$STACK" ]]; then
  echo "Usage: $0 <stack-name>"
  exit 2
fi

TAG="stack:${STACK}"
DEST_DIR="${DEST_ROOT}/${STACK}"
mkdir -p "$DEST_DIR"

op vault get "$VAULT" >/dev/null

op item list --vault "$VAULT" --format=json |
jq -r --arg tag "$TAG" '
  .[]
  | select((.title | endswith(".env")) and ((.tags // []) | index($tag)))
  | .id
' | while read -r ITEM_ID; do
  ITEM_JSON="$(op item get "$ITEM_ID" --vault "$VAULT" --format=json)"
  TITLE="$(echo "$ITEM_JSON" | jq -r '.title')"
  OUT="${DEST_DIR}/${TITLE}"

  echo "$ITEM_JSON" | jq -r '
    .fields[]?
    | select(.label? and (.value? != null))
    | "\(.label)=\(.value)"
  ' > "$OUT"
done
