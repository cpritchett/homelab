#!/usr/bin/env bash
set -euo pipefail

IMAGE="${NIX_DOCKER_IMAGE:-nixos/nix:2.24.14}"
PLATFORM="${NIX_DOCKER_PLATFORM:-linux/amd64}"
WORKDIR="${PWD}"
DOCKER_ARGS=()

if git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null)"; then
  DOCKER_ARGS+=(-v "${git_dir}:${git_dir}")
fi

if git_common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
  if [ -n "${git_common_dir}" ] && [ "${git_common_dir}" != "${git_dir:-}" ]; then
    DOCKER_ARGS+=(-v "${git_common_dir}:${git_common_dir}")
  fi
fi

usage() {
  cat <<EOF
Usage: $0 [nix args...]

Run nix inside an ephemeral Docker container with the current repository mounted.
For artifact-producing workflows, prefer repo scripts that copy outputs into the
workspace before the container exits.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required for isolated nix usage" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  set -- repl
fi

exec docker run --rm \
  --platform "$PLATFORM" \
  -e HOME=/root \
  -e NIX_CONFIG=$'experimental-features = nix-command flakes\nsandbox = false' \
  -v "$WORKDIR:$WORKDIR" \
  "${DOCKER_ARGS[@]}" \
  -w "$WORKDIR" \
  "$IMAGE" \
  sh -lc 'git config --global --add safe.directory "$1" && shift && exec nix --option sandbox false --option filter-syscalls false "$@"' \
  sh "$WORKDIR" "$@"
