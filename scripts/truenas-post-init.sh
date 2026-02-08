#!/bin/bash
###############################################################################
# TrueNAS Post-Init Script
#
# Place this at: /root/scripts/truenas-post-init.sh
# Configure via: System Settings → Advanced → Init/Shutdown Scripts
#   Type: Command
#   When: Post Init
#   Command: /root/scripts/truenas-post-init.sh
#   Timeout: 600
###############################################################################

# Wait for Docker to be ready
sleep 10

# Run the bootstrap script
/mnt/apps01/repos/homelab/scripts/truenas-init-bootstrap.sh

exit 0
