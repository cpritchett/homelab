#!/usr/bin/env bash
set -euo pipefail

on_error() {
  echo "ERROR: permission script failed (line $1)." >&2
}
trap 'on_error $LINENO' ERR

log() {
  echo "$@"
}

warn() {
  echo "WARN: $@" >&2
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (or with sudo) to change ownership on /mnt paths."
  exit 1
fi

ensure_dir() {
  local path="$1"
  if [ ! -d "$path" ]; then
    mkdir -p "$path"
  fi
}

chown_recursive() {
  local owner="$1"
  local path="$2"
  ensure_dir "$path"
  chown -R "$owner" "$path"
}

chmod_recursive() {
  local mode="$1"
  local path="$2"
  if [ -d "$path" ]; then
    chmod -R "$mode" "$path"
  fi
}

log "Setting ownership for stack data directories..."

# Caddy
chown_recursive 1701:1702 /mnt/apps01/appdata/proxy/caddy-data
chown_recursive 1701:1702 /mnt/apps01/appdata/proxy/caddy-config

# op-connect credentials file
ensure_dir /mnt/apps01/secrets/op
if [ -f /mnt/apps01/secrets/op/1password-credentials.json ]; then
  chown 999:999 /mnt/apps01/secrets/op/1password-credentials.json
  chmod 600 /mnt/apps01/secrets/op/1password-credentials.json
else
  warn "/mnt/apps01/secrets/op/1password-credentials.json not found; skipping."
fi

# op-connect data volume (if it exists)
if command -v docker >/dev/null 2>&1; then
  if docker volume inspect op-connect_op-connect-data >/dev/null 2>&1; then
    vol_path="$(docker volume inspect op-connect_op-connect-data --format '{{.Mountpoint}}')"
    if [ -n "$vol_path" ] && [ -d "$vol_path" ]; then
      chown -R 999:999 "$vol_path"
    else
      warn "op-connect volume mountpoint not found; skipping."
    fi
  else
    warn "docker volume op-connect_op-connect-data not found; deploy op-connect first if you want volume ownership set."
  fi
else
  warn "docker not available; skipping op-connect volume ownership."
fi

# Forgejo
chown_recursive 1000:1000 /mnt/apps01/appdata/forgejo
chown_recursive 999:999 /mnt/apps01/appdata/forgejo/postgres

# Authentik
chown_recursive 999:999 /mnt/apps01/appdata/authentik/postgres
chown_recursive 999:1000 /mnt/apps01/appdata/authentik/redis
chown_recursive 1000:1000 /mnt/apps01/appdata/authentik/media
chown_recursive 1000:1000 /mnt/apps01/appdata/authentik/custom-templates

# Woodpecker
chown_recursive 1000:1000 /mnt/apps01/appdata/woodpecker

# Uptime Kuma
chown_recursive 1000:1000 /mnt/apps01/appdata/uptime-kuma

# Restic cache
chown_recursive 0:0 /mnt/apps01/appdata/restic/cache

# Optional: tighten directory permissions for app data
chmod_recursive 755 /mnt/apps01/appdata/forgejo
chmod_recursive 755 /mnt/apps01/appdata/forgejo
chmod_recursive 755 /mnt/apps01/appdata/woodpecker

log "Done."
