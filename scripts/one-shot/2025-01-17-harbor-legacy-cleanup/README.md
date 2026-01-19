# Harbor Legacy Cleanup

**Date:** 2025-01-17  
**Purpose:** Clean up broken legacy Harbor stack from old deployment method  
**Status:** Ready to run  

## Context

Harbor was previously deployed using an older method at `/mnt/apps01/appdata/stacks-repo/stacks/20-harbor/` but became "broken-in-place" and non-functional. The new deployment system uses sparse checkout at `/mnt/apps01/appdata/stacks/homelab/stacks/harbor/` with registry-based ordering.

This script safely removes the legacy broken Harbor installation while preserving data volumes and archiving the configuration for reference.

## What This Script Does

1. **Stops legacy Harbor containers** (they're broken anyway)
2. **Archives legacy stack** to timestamped directory for reference
3. **Removes legacy directory** `/mnt/apps01/appdata/stacks-repo/stacks/20-harbor/`
4. **Cleans up empty parent** directory if no other stacks remain
5. **Preserves data volumes** at `/mnt/apps01/appdata/harbor/runtime/`

## Prerequisites

- Current homelab sparse checkout exists at `/mnt/apps01/appdata/stacks/homelab/`
- Legacy Harbor stack exists at `/mnt/apps01/appdata/stacks-repo/stacks/20-harbor/`
- Root/sudo access on NAS

## Usage

```bash
# Run on the NAS
cd /path/to/homelab/scripts/one-shot/2025-01-17-harbor-legacy-cleanup
sudo ./cleanup-harbor-legacy.sh
```

## Safety Measures

- **Archives before deletion** - Complete copy to timestamped archive
- **Verification checks** - Ensures current sparse checkout exists
- **Data protection** - Never touches `/mnt/apps01/appdata/harbor/runtime/`
- **Rollback capability** - Archived files can be restored if needed

## Post-Cleanup

After running this script, deploy Harbor from the new stack:

```bash
cd /mnt/apps01/appdata/stacks/homelab/stacks
./deploy-stack harbor
```

## Completion Criteria

- [ ] Legacy directory `/mnt/apps01/appdata/stacks-repo/stacks/20-harbor/` removed
- [ ] Legacy stack archived to `/mnt/apps01/appdata/archive/harbor-broken-legacy-*`
- [ ] Harbor containers stopped and cleaned up
- [ ] New Harbor stack successfully deployed
- [ ] Harbor accessible at https://harbor.in.hypyr.space

## Rollback

If needed, restore from archive:

```bash
# Find the archive
ls -la /mnt/apps01/appdata/archive/harbor-broken-legacy-*

# Restore (adjust timestamp as needed)
sudo cp -r /mnt/apps01/appdata/archive/harbor-broken-legacy-20250117-*/20-harbor /mnt/apps01/appdata/stacks-repo/stacks/
```

## Related

- **ADR-0023:** [Script Organization Requirements](../../../docs/adr/ADR-0023-script-organization-requirements.md)
- **New Harbor Stack:** `/mnt/apps01/appdata/stacks/homelab/stacks/harbor/`
- **Deployment Docs:** [docs/operations/stacks/lifecycle.md](../../../docs/operations/stacks/lifecycle.md)