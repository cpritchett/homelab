#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${1:-$PWD/.tmp/broadside-netboot}"
TARGET_HOST="${BROADSIDE_PXE_HOST:-root@barbary}"
TARGET_DIR="${BROADSIDE_PXE_TARGET_DIR:-/mnt/apps01/repos/homelab/stacks/infrastructure/pxe/assets/broadside}"

usage() {
  cat <<EOF
Usage: $0 [source-dir]

Sync prebuilt Broadside NixOS netboot assets to barbary's repo-served PXE asset path.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "Source directory not found: $SRC_DIR" >&2
  exit 1
fi

for f in bzImage initrd netboot.ipxe homelab.tar.gz nixpkgs.tar.gz disko.tar.gz; do
  if [ ! -e "$SRC_DIR/$f" ]; then
    echo "Missing required asset: $SRC_DIR/$f" >&2
    exit 1
  fi
done

ssh "$TARGET_HOST" "mkdir -p '$TARGET_DIR'"
rsync -av "$SRC_DIR"/ "$TARGET_HOST:$TARGET_DIR/"

echo "Synced Broadside installer assets to $TARGET_HOST:$TARGET_DIR"
