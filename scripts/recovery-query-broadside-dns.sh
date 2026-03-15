#!/usr/bin/env bash
set -euo pipefail

SERVER="${BROADSIDE_DNS_SERVER:-broadside}"
NAME="${1:-broadside.in.hypyr.space}"

cat <<EOF
== querying broadside DNS ==
server: $SERVER
name:   $NAME
EOF

if command -v dig >/dev/null 2>&1; then
  dig @"$SERVER" "$NAME"
elif command -v drill >/dev/null 2>&1; then
  drill @"$SERVER" "$NAME"
else
  echo "Neither dig nor drill is installed." >&2
  exit 1
fi
