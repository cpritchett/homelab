#!/usr/bin/env bash
set -euo pipefail

FROM_HOST="root@barbary"
SOURCE_DIR="/mnt/apps01/appdata/step-ca"
BACKUP_DIR="${STEP_CA_BACKUP_DIR:-$PWD/.tmp/step-ca-backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<EOF
Usage: $0 [--from-host user@host] [--source-dir path] [--backup-dir path]

Create a tar.gz backup archive of the barbary Step-CA state directory.

This script is read-only on the source host. It streams a tar archive over SSH
and writes it locally to the backup directory.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --from-host)
      FROM_HOST="$2"
      shift 2
      ;;
    --source-dir)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --backup-dir)
      BACKUP_DIR="$2"
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

mkdir -p "$BACKUP_DIR"

ARCHIVE_PATH="$BACKUP_DIR/step-ca-backup-$STAMP.tgz"
LATEST_PATH="$BACKUP_DIR/step-ca-backup-latest.tgz"

echo "Creating Step-CA backup archive from $FROM_HOST:$SOURCE_DIR"
ssh "$FROM_HOST" "tar -C '$SOURCE_DIR' -czf - ." > "$ARCHIVE_PATH"
cp "$ARCHIVE_PATH" "$LATEST_PATH"

echo "Wrote:"
echo "  $ARCHIVE_PATH"
echo "  $LATEST_PATH"
