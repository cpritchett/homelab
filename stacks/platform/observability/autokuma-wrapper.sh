#!/bin/sh
# Inject API key from Docker secret into environment variable
export AUTOKUMA__KUMA__HEADERS="x-api-key=$(cat /run/secrets/uptime_kuma_api_key)"
# Execute AutoKuma with full path
exec /usr/local/bin/autokuma
