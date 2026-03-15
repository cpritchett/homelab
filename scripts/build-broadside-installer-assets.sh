#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-$PWD/stacks/infrastructure/pxe/assets/broadside}"
BASE_URL="${BROADSIDE_PXE_BASE_URL:-http://10.0.5.121:8480/assets/broadside}"
FLAKE_REF="path:$PWD"
NIX_DOCKER_PLATFORM="${NIX_DOCKER_PLATFORM:-linux/amd64}"
NIX_COMMON_ARGS=(--option sandbox false --option filter-syscalls false)
DOCKER_ARGS=()

if git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null)"; then
  DOCKER_ARGS+=(-v "${git_dir}:${git_dir}")
fi

if git_common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
  if [ -n "${git_common_dir}" ] && [ "${git_common_dir}" != "${git_dir:-}" ]; then
    DOCKER_ARGS+=(-v "${git_common_dir}:${git_common_dir}")
  fi
fi

extract_archive_input_path() {
  local archive_json="$1"
  local input_name="$2"

  if command -v jq >/dev/null 2>&1; then
    printf '%s\n' "$archive_json" | jq -r --arg input_name "$input_name" '.inputs[$input_name].path'
    return
  fi

  local archive_file
  archive_file="$(mktemp)"
  printf '%s\n' "$archive_json" > "$archive_file"
  nix "${NIX_COMMON_ARGS[@]}" eval --impure --raw --expr "
    let
      archive = builtins.fromJSON (builtins.readFile ${archive_file});
    in archive.inputs.${input_name}.path
  "
  rm -f "$archive_file"
}

rewrite_ipxe_asset_paths() {
  local source_path="$1"
  local output_path="$2"
  local kernel_rewritten=0
  local initrd_rewritten=0
  local line

  : > "$output_path"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$kernel_rewritten" -eq 0 ] && [[ "$line" =~ ^([[:space:]]*kernel[[:space:]]+)([^[:space:]]+)(.*)$ ]]; then
      printf '%s%s%s\n' "${BASH_REMATCH[1]}" "${BASE_URL}/bzImage" "${BASH_REMATCH[3]}" >> "$output_path"
      kernel_rewritten=1
      continue
    fi

    if [ "$initrd_rewritten" -eq 0 ] && [[ "$line" =~ ^([[:space:]]*initrd[[:space:]]+)([^[:space:]]+)(.*)$ ]]; then
      printf '%s%s%s\n' "${BASH_REMATCH[1]}" "${BASE_URL}/initrd" "${BASH_REMATCH[3]}" >> "$output_path"
      initrd_rewritten=1
      continue
    fi

    printf '%s\n' "$line" >> "$output_path"
  done < "$source_path"
}

usage() {
  cat <<EOF
Usage: $0 [output-dir]

Build the Broadside NixOS netboot assets from the flake and copy them into a
directory that can be synced to barbary's PXE assets path.

Required tools:
  nix or docker
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if ! command -v nix >/dev/null 2>&1; then
  if [ "${BROADSIDE_ASSET_BUILD_IN_DOCKER:-0}" = "1" ]; then
    echo "nix is required inside the build container" >&2
    exit 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "either nix or docker is required" >&2
    exit 1
  fi

  mkdir -p "$OUT_DIR"
  exec docker run --rm \
    --platform "$NIX_DOCKER_PLATFORM" \
    -e HOME=/root \
    -e NIX_CONFIG=$'experimental-features = nix-command flakes\nsandbox = false' \
    -e BROADSIDE_ASSET_BUILD_IN_DOCKER=1 \
    -e BROADSIDE_PXE_BASE_URL="$BASE_URL" \
    -e NIX_DOCKER_PLATFORM="$NIX_DOCKER_PLATFORM" \
    -v "$PWD:$PWD" \
    "${DOCKER_ARGS[@]}" \
    -w "$PWD" \
    nixos/nix:2.24.14 \
    sh -lc 'git config --global --add safe.directory "$1" && shift && exec sh "$@"' \
    sh "$PWD" "$PWD/scripts/build-broadside-installer-assets.sh" "$OUT_DIR"
fi

mkdir -p "$OUT_DIR"

kernel_out="$(nix "${NIX_COMMON_ARGS[@]}" build --no-link --print-out-paths "$FLAKE_REF#nixosConfigurations.broadside-installer.config.system.build.kernel")"
initrd_out="$(nix "${NIX_COMMON_ARGS[@]}" build --no-link --print-out-paths "$FLAKE_REF#nixosConfigurations.broadside-installer.config.system.build.netbootRamdisk")"
ipxe_out="$(nix "${NIX_COMMON_ARGS[@]}" build --no-link --print-out-paths "$FLAKE_REF#nixosConfigurations.broadside-installer.config.system.build.netbootIpxeScript")"
archive_json="$(nix "${NIX_COMMON_ARGS[@]}" flake archive --json "$FLAKE_REF")"
nixpkgs_src="$(extract_archive_input_path "$archive_json" nixpkgs)"
disko_src="$(extract_archive_input_path "$archive_json" disko)"

kernel_path="$(find "$kernel_out" -type f \( -name bzImage -o -name vmlinuz -o -name linux \) | head -n 1)"
ipxe_path="$(find "$ipxe_out" -type f \( -name netboot.ipxe -o -name '*.ipxe' \) | head -n 1)"

if [ -z "$kernel_path" ] || [ -z "$ipxe_path" ] || [ -z "$nixpkgs_src" ] || [ -z "$disko_src" ]; then
  echo "Failed to locate generated installer artifacts or locked flake inputs" >&2
  exit 1
fi

cp "$kernel_path" "$OUT_DIR/bzImage"

if [ -f "$initrd_out" ]; then
  cp "$initrd_out" "$OUT_DIR/initrd"
else
  initrd_path="$(find "$initrd_out" -type f | head -n 1)"
  cp "$initrd_path" "$OUT_DIR/initrd"
fi

rewrite_ipxe_asset_paths "$ipxe_path" "$OUT_DIR/netboot.ipxe"

tar --exclude='.git' --exclude='.tmp' --exclude='result' -czf "$OUT_DIR/homelab.tar.gz" .
tar -C "$nixpkgs_src" -czf "$OUT_DIR/nixpkgs.tar.gz" .
tar -C "$disko_src" -czf "$OUT_DIR/disko.tar.gz" .

cat <<EOF
Broadside netboot assets ready in:
  $OUT_DIR

Sync them to barbary:
  rsync -av "$OUT_DIR"/ root@barbary:/mnt/apps01/repos/homelab/stacks/infrastructure/pxe/assets/broadside/
EOF
