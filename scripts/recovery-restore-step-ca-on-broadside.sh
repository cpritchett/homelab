#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${BROADSIDE_HOST:-root@broadside}"
TARGET_DIR="${BROADSIDE_STEP_CA_DIR:-/srv/recovery/appdata/step-ca}"
ARCHIVE=""
APPLY=0

usage() {
  cat <<EOF
Usage: $0 --archive path [--target-host user@host] [--target-dir path] [--apply]

Restore a Step-CA backup archive onto broadside.

Default mode is dry-run. Use --apply to actually copy and extract the archive.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive)
      ARCHIVE="$2"
      shift 2
      ;;
    --target-host)
      TARGET_HOST="$2"
      shift 2
      ;;
    --target-dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
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

if [ -z "$ARCHIVE" ]; then
  echo "--archive is required" >&2
  usage >&2
  exit 1
fi

if [ ! -f "$ARCHIVE" ]; then
  echo "Archive not found: $ARCHIVE" >&2
  exit 1
fi

echo "== step-ca restore plan =="
echo "target host: $TARGET_HOST"
echo "target dir:  $TARGET_DIR"
echo "archive:     $ARCHIVE"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "Dry run only. Re-run with --apply to perform the restore."
  exit 0
fi

ssh "$TARGET_HOST" "mkdir -p '$TARGET_DIR'"
scp "$ARCHIVE" "$TARGET_HOST:$TARGET_DIR/restore.tgz"
ssh "$TARGET_HOST" "
  rm -rf '$TARGET_DIR'/config '$TARGET_DIR'/certs '$TARGET_DIR'/secrets '$TARGET_DIR'/db '$TARGET_DIR'/templates '$TARGET_DIR'/issued
  tar -C '$TARGET_DIR' -xzf '$TARGET_DIR/restore.tgz'
  rm -f '$TARGET_DIR/restore.tgz'
  find '$TARGET_DIR' -maxdepth 2 -type d | sort
"

cat <<EOF
Restore complete.

Next steps:
1. Start or restart the broadside Step-CA service.
2. Verify health:
   ssh $TARGET_HOST 'step ca health --ca-url https://localhost:9000 --root $TARGET_DIR/certs/root_ca.crt'
3. Repoint only the clients that require PKI during recovery.
EOF
