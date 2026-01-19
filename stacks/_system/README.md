# TrueNAS System Integration (Optional Failsafe)

This directory contains optional system-level hooks for TrueNAS SCALE. **Komodo Core and Periphery are the primary deployment mechanism.** These scripts serve as optional failsafe bootstrapping only.

## Primary vs Failsafe Deployment

- **Primary**: Komodo Core schedules deployments via Periphery
- **Failsafe**: TrueNAS init script (this directory) for emergency bootstrap only

## Directory Structure

- **`init/`** - Optional init scripts (Post-Init Scripts in TrueNAS UI)

## Init Scripts (Optional)

Init scripts are **optional failsafe mechanisms** that run after TrueNAS boots. Use only if:
- Komodo is not available
- Emergency bootstrap is needed
- Testing deployment scripts

### `init/10-homelab-stacks.sh`

Optional bootstrap script that runs `sync-and-deploy` in background with timeout and logging.

**Setup (Optional):**
1. TrueNAS UI → System Settings → Advanced → Init/Shutdown Scripts
2. Add Post-Init Script
3. Type: `Script`
4. Script: `/mnt/apps01/appdata/stacks/checkout/stacks/_system/init/10-homelab-stacks.sh`
5. When: `Post Init`

**Logging:**
- Logs to `/mnt/apps01/appdata/logs/stacks/bootstrap.log`
- Includes timestamps and deployment status
- Safe to run multiple times (idempotent)

## Removed Components

- **Cron scripts**: Removed in favor of Komodo scheduling
- **Automatic nightly deployments**: Handled by Komodo Core

## References

- [Komodo Deployment Guide](../../docs/STACKS_KOMODO.md) - Primary deployment method
- [TrueNAS SCALE Documentation](https://www.truenas.com/docs/scale/)
- [Stack Deployment Scripts](../_bin/README.md)
