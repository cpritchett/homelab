#!/bin/sh
# Inject API key from Docker secret as password
# Uptime Kuma API keys work by passing the key as the password with empty username
export AUTOKUMA__KUMA__USERNAME=""
export AUTOKUMA__KUMA__PASSWORD="$(cat /run/secrets/uptime_kuma_api_key)"
# Execute AutoKuma with full path
exec /usr/local/bin/autokuma
