#!/bin/sh
# Inject Uptime Kuma credentials from Docker secrets
export AUTOKUMA__KUMA__USERNAME="$(cat /run/secrets/uptime_kuma_username)"
export AUTOKUMA__KUMA__PASSWORD="$(cat /run/secrets/uptime_kuma_password)"
# Execute AutoKuma with full path
exec /usr/local/bin/autokuma
