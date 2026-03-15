#!/usr/bin/env bash
set -euo pipefail

HOST="${BROADSIDE_HOST:-root@broadside}"
RUNBOOK_URL="${BROADSIDE_RUNBOOK_URL:-http://broadside.in.hypyr.space/}"
MIRROR_DIR="${BROADSIDE_MIRROR_DIR:-/srv/recovery/mirror}"
STEP_CA_BACKUP_DIR="${BROADSIDE_STEP_CA_BACKUP_DIR:-/srv/recovery/backups/step-ca}"

usage() {
  cat <<EOF
Usage: $0 [--host user@host] [--runbook-url url]

Read-only readiness checks for the broadside recovery node.

Environment overrides:
  BROADSIDE_HOST
  BROADSIDE_RUNBOOK_URL
  BROADSIDE_MIRROR_DIR
  BROADSIDE_STEP_CA_BACKUP_DIR
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --runbook-url)
      RUNBOOK_URL="$2"
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

echo "== broadside host check =="
ssh "$HOST" "hostname && uptime"

echo
echo "== service status =="
ssh "$HOST" "
  systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null || true
  systemctl is-active tailscaled 2>/dev/null || true
  systemctl is-active unbound 2>/dev/null || true
  systemctl is-active caddy 2>/dev/null || true
"

echo
echo "== runbook site =="
curl -fsSIL "$RUNBOOK_URL" | sed -n '1,10p'

echo
echo "== mirror directory =="
ssh "$HOST" "
  if [ -d '$MIRROR_DIR' ]; then
    find '$MIRROR_DIR' -maxdepth 2 -mindepth 1 | sort | sed -n '1,20p'
  else
    echo 'missing: $MIRROR_DIR'
  fi
"

echo
echo "== step-ca backup archive =="
ssh "$HOST" "
  if [ -d '$STEP_CA_BACKUP_DIR' ]; then
    ls -lh '$STEP_CA_BACKUP_DIR' | tail -n 5
  else
    echo 'missing: $STEP_CA_BACKUP_DIR'
  fi
"
