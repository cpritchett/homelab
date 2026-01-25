#!/bin/sh
set -eu

task="${RESTIC_TASK:-backup}"

# Required env vars (fail fast)
: "${RESTIC_REPOSITORY:?}"
: "${RESTIC_PASSWORD:?}"

# For SeaweedFS S3 (or any S3-compatible)
: "${AWS_ACCESS_KEY_ID:?}"
: "${AWS_SECRET_ACCESS_KEY:?}"
: "${AWS_ENDPOINT:?}"

# Optional but recommended
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/tmp/restic-cache}"
export RESTIC_HOST="${RESTIC_HOST:-barbary}"
export RESTIC_TAGS="${RESTIC_TAGS:-homelab}"
export RESTIC_EXCLUDE_FILE="${RESTIC_EXCLUDE_FILE:-/scripts/excludes.txt}"

# Initialize repo if needed (idempotent)
restic snapshots >/dev/null 2>&1 || restic init

case "$task" in
  backup)
    echo "==> restic backup (host=$RESTIC_HOST tags=$RESTIC_TAGS)"
    restic backup \
      --host "$RESTIC_HOST" \
      --tag "$RESTIC_TAGS" \
      --exclude-file "$RESTIC_EXCLUDE_FILE" \
      /src/apps01/appdata \
      /src/apps01/secrets \
      /src/data01/appdata

    echo "==> forget/prune (light) — keep repo tidy"
    restic forget --prune \
      --host "$RESTIC_HOST" \
      --keep-daily 14 \
      --keep-weekly 8 \
      --keep-monthly 12
    ;;

  prune)
    echo "==> restic prune (heavier maintenance)"
    restic prune
    ;;

  check)
    echo "==> restic check"
    # --read-data-subset keeps it reasonable; tweak as you like
    restic check --read-data-subset=5%
    ;;

  snapshots)
    restic snapshots
    ;;

  *)
    echo "Unknown RESTIC_TASK: $task"
    exit 2
    ;;
esac
