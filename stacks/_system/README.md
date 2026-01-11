# TrueNAS System Integration

This directory contains system-level hooks for integrating stack deployment with TrueNAS SCALE.

## Directory Structure

- **`init/`** - Init scripts (Post-Init Scripts in TrueNAS UI)
- **`cron/`** - Cron job scripts (scheduled tasks)

## Init Scripts

Init scripts run after TrueNAS boots. They should be:
- Idempotent (safe to run multiple times)
- Fast (avoid blocking boot process)
- Logged (output goes to system logs)

### `init/10-homelab-stacks.sh`

Deploys homelab stacks after TrueNAS boot. This ensures containers are running even after system restart.

**Setup:**
1. TrueNAS UI → System Settings → Advanced → Init/Shutdown Scripts
2. Add Post-Init Script
3. Type: `Script`
4. Script: `/mnt/apps01/appdata/stacks/homelab/stacks/_system/init/10-homelab-stacks.sh`
5. When: `Post Init`

## Cron Scripts

Cron scripts run on a schedule to keep stacks up-to-date.

### `cron/deploy-stacks.sh`

Pulls latest code and redeploys stacks. Use for automatic updates.

**Setup:**
1. TrueNAS UI → System Settings → Advanced → Cron Jobs
2. Add Cron Job
3. Description: `Sync and deploy homelab stacks`
4. Command: `/mnt/apps01/appdata/stacks/homelab/stacks/_system/cron/deploy-stacks.sh`
5. Schedule: Custom (e.g., daily at 3 AM)
6. User: `root`
7. Hide Standard Output: `No`
8. Hide Standard Error: `No`

## References

- [TrueNAS SCALE Documentation](https://www.truenas.com/docs/scale/)
- [Stack Deployment Scripts](../_bin/README.md)
