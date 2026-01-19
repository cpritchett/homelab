#!/bin/bash
# Harbor Legacy Cleanup (Corrected for Sparse Checkout)
set -euo pipefail

LEGACY_STACK="/mnt/apps01/appdata/stacks-repo/stacks/20-harbor"
ARCHIVE_BASE="/mnt/apps01/appdata/archive"
ARCHIVE_DIR="$ARCHIVE_BASE/harbor-broken-legacy-$(date +%Y%m%d-%H%M%S)"
CURRENT_HOMELAB="/mnt/apps01/appdata/stacks/homelab"
NEW_STACK="$CURRENT_HOMELAB/stacks/harbor"

echo "=== Harbor Legacy Cleanup (Sparse Checkout Aware) ==="
echo "Legacy stack: $LEGACY_STACK (broken, old deployment method)"
echo "Current homelab: $CURRENT_HOMELAB (sparse checkout)"
echo "New stack: $NEW_STACK (registry-based)"
echo "Archive location: $ARCHIVE_DIR"
echo

# Verify current sparse checkout exists
if [[ ! -d "$CURRENT_HOMELAB" ]]; then
    echo "❌ ERROR: Current homelab sparse checkout not found at $CURRENT_HOMELAB"
    echo "   Run: /mnt/apps01/appdata/stacks/homelab/stacks/_bin/sync-and-deploy"
    exit 1
fi

# Check if legacy directory exists
if [[ ! -d "$LEGACY_STACK" ]]; then
    echo "✅ No legacy Harbor stack found at $LEGACY_STACK - nothing to clean"
    exit 0
fi

echo "📋 Legacy stack contents (broken, old method):"
ls -la "$LEGACY_STACK"
echo

# Stop any running Harbor containers from legacy stack
echo "🛑 Stopping any running Harbor containers from legacy stack..."
cd "$LEGACY_STACK"
if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yml" ]]; then
    sudo docker compose down --remove-orphans 2>/dev/null || true
    echo "   Stopped legacy Harbor containers"
fi

# Clean up orphaned containers
sudo docker rm -f $(sudo docker ps -aq --filter "name=harbor") 2>/dev/null || true

# Archive legacy stack
sudo mkdir -p "$ARCHIVE_DIR"
echo "📦 Archiving legacy stack..."
sudo cp -r "$LEGACY_STACK" "$ARCHIVE_DIR/"

# Verify and remove
ARCHIVED_STACK="$ARCHIVE_DIR/$(basename "$LEGACY_STACK")"
if [[ -d "$ARCHIVED_STACK" ]]; then
    echo "✅ Archive completed: $ARCHIVED_STACK"
    
    echo "🗑️  Removing legacy stack directory..."
    sudo rm -rf "$LEGACY_STACK"
    
    # Also check if we can remove the parent stacks-repo if it's empty
    LEGACY_PARENT="/mnt/apps01/appdata/stacks-repo"
    if [[ -d "$LEGACY_PARENT" ]] && [[ -z "$(ls -A "$LEGACY_PARENT" 2>/dev/null)" ]]; then
        echo "🗑️  Removing empty legacy parent directory..."
        sudo rm -rf "$LEGACY_PARENT"
        echo "   Removed: $LEGACY_PARENT"
    fi
    
    echo "✅ Legacy cleanup completed"
else
    echo "❌ Archive failed - NOT removing legacy"
    exit 1
fi

echo
echo "📍 Summary:"
echo "   ✅ Legacy stack archived: $ARCHIVED_STACK"
echo "   ✅ Legacy directory removed: $LEGACY_STACK"
echo "   ✅ Current sparse checkout preserved: $CURRENT_HOMELAB"
echo
echo "🚀 Ready to deploy Harbor from current stack:"
echo "   cd $CURRENT_HOMELAB/stacks"
echo "   ./deploy-stack harbor"

echo
echo "🎉 Harbor legacy cleanup completed!"