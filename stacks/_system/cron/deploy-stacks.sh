#!/usr/bin/env bash
set -euo pipefail

# Deploy all homelab stacks on schedule (cron)
# Note: Intentionally duplicated from init script for clarity and independence
/mnt/apps01/appdata/stacks/homelab/stacks/_bin/sync-and-deploy
