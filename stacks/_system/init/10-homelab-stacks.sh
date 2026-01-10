#!/usr/bin/env bash
set -euo pipefail

# Deploy all homelab stacks on TrueNAS boot
# Note: Intentionally duplicated from cron script for clarity and independence
/mnt/apps01/appdata/stacks/homelab/stacks/_bin/sync-and-deploy
