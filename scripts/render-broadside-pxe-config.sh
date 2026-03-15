#!/bin/sh

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DNSMASQ_TEMPLATE="${REPO_ROOT}/stacks/infrastructure/pxe/templates/dnsmasq-broadside.conf.template"
DNSMASQ_OUTPUT="${REPO_ROOT}/stacks/infrastructure/pxe/dnsmasq.d/broadside.conf"
MATCHBOX_TEMPLATE="${REPO_ROOT}/stacks/infrastructure/pxe/matchbox/groups/broadside.json.template"
MATCHBOX_OUTPUT="${REPO_ROOT}/stacks/infrastructure/pxe/matchbox/groups/broadside.json"

log() {
  echo "[broadside-pxe-render] $*"
}

mkdir -p "$(dirname "$DNSMASQ_OUTPUT")" "$(dirname "$MATCHBOX_OUTPUT")"

render_with_local_op() {
  op inject -i "$DNSMASQ_TEMPLATE" -o "$DNSMASQ_OUTPUT" -f
  op inject -i "$MATCHBOX_TEMPLATE" -o "$MATCHBOX_OUTPUT" -f
}

render_with_connect() {
  CONNECT_TOKEN_FILE="${OP_CONNECT_TOKEN_PATH:-/mnt/apps01/secrets/op/connect-token}"

  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required to render Broadside PXE config via 1Password Connect." >&2
    exit 1
  fi

  if [ ! -r "$CONNECT_TOKEN_FILE" ]; then
    echo "1Password Connect token not readable at $CONNECT_TOKEN_FILE" >&2
    exit 1
  fi

  if ! docker network inspect op-connect_op-connect >/dev/null 2>&1; then
    echo "op-connect_op-connect network not found. Deploy infrastructure tier first." >&2
    exit 1
  fi

  docker run --rm \
    --network op-connect_op-connect \
    -e OP_CONNECT_HOST=http://op-connect-api:8080 \
    -v "${REPO_ROOT}:${REPO_ROOT}" \
    -v "${CONNECT_TOKEN_FILE}:/run/secrets/op_connect_token:ro" \
    -w "${REPO_ROOT}" \
    1password/op:2 sh -lc '
      set -eu
      export OP_CONNECT_TOKEN="$(cat /run/secrets/op_connect_token)"
      op inject -i "'"${DNSMASQ_TEMPLATE}"'" -o "'"${DNSMASQ_OUTPUT}"'" -f
      op inject -i "'"${MATCHBOX_TEMPLATE}"'" -o "'"${MATCHBOX_OUTPUT}"'" -f
    '
}

if command -v op >/dev/null 2>&1 && op whoami >/dev/null 2>&1; then
  render_with_local_op
else
  render_with_connect
fi

for rendered_file in "$DNSMASQ_OUTPUT" "$MATCHBOX_OUTPUT"; do
  if rg -n "op://" "$rendered_file" >/dev/null 2>&1; then
    echo "Unresolved 1Password reference remained in $rendered_file" >&2
    exit 1
  fi
done

chmod 0644 "$DNSMASQ_OUTPUT" "$MATCHBOX_OUTPUT"
log "Rendered Broadside PXE config from 1Password inventory."
