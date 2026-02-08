#!/bin/bash
###############################################################################
# TrueNAS Post-Init Script
#
# This script lives in the repository at:
#   /mnt/apps01/repos/homelab/scripts/truenas-post-init.sh
#
# Configure via TrueNAS UI:
#   System Settings → Advanced → Init/Shutdown Scripts
#   - Type: Command
#   - When: Post Init
#   - Command: /mnt/apps01/repos/homelab/scripts/truenas-post-init.sh
#   - Timeout: 600
#   - Enabled: ✓
#
# This path is on a persistent dataset and will survive system upgrades.
###############################################################################

# Wait for Docker to be ready
sleep 10

# Run the bootstrap script (same directory)
/mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh

exit 0
