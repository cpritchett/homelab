#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage:
  ./scripts/upsert-broadside-pxe-op-item.sh --mac <PXE_MAC> --reserved-ip <IP>

Creates or updates the 1Password item used to render Broadside PXE config.
Item path:
  op://homelab/broadside-pxe/pxe_mac
  op://homelab/broadside-pxe/reserved_ip
EOF
}

MAC=""
RESERVED_IP=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mac)
      MAC="${2:-}"
      shift 2
      ;;
    --reserved-ip)
      RESERVED_IP="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$MAC" ] || [ -z "$RESERVED_IP" ]; then
  usage >&2
  exit 1
fi

if ! command -v op >/dev/null 2>&1; then
  echo "op CLI is required." >&2
  exit 1
fi

if ! op whoami >/dev/null 2>&1; then
  echo "op CLI is not signed in. Run 'op signin --account pritchett-brittain-famil.1password.com' first." >&2
  exit 1
fi

ITEM_ID="$(op item list --vault homelab --format json | jq -r '.[] | select(.title=="broadside-pxe") | .id' | head -n1)"

if [ -n "$ITEM_ID" ]; then
  op item edit "$ITEM_ID" \
    --vault homelab \
    "pxe_mac[concealed]=$MAC" \
    "reserved_ip[concealed]=$RESERVED_IP" >/dev/null
  echo "Updated op://homelab/broadside-pxe/*"
else
  op item create \
    --vault homelab \
    --category "Secure Note" \
    --title broadside-pxe \
    "pxe_mac[concealed]=$MAC" \
    "reserved_ip[concealed]=$RESERVED_IP" >/dev/null
  echo "Created op://homelab/broadside-pxe/*"
fi
