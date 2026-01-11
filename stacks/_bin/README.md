# Stack Deployment Utilities

This directory contains helper scripts for deploying Docker Compose stacks on TrueNAS SCALE.

## Scripts

- **`sync-and-deploy`** - Sparse-checkout the homelab repo and run deployment
- **`deploy-all`** - Deploy all stacks in dependency order (from `stacks/registry.toml`)
- **`deploy-stack`** - Deploy a single stack directory
- **`op-inject`** - Wrapper for 1Password CLI to inject secrets
- **`ensure-harbor-datasets`** - Initialize Harbor ZFS datasets and mountpoints

## Usage

These scripts are designed to run on the TrueNAS host, typically:
- Via init scripts (`stacks/_system/init/`)
- Via cron jobs (`stacks/_system/cron/`)
- Manually for testing/troubleshooting

## Installation

The `sync-and-deploy` script handles installation automatically:
1. Sparse-checkout required paths from GitHub
2. Install `op-inject` to `/mnt/apps01/appdata/bin/`
3. Run `deploy-all` to deploy all stacks

## Path Conventions

- **Repository checkout:** `/mnt/apps01/appdata/stacks/homelab/`
- **System binaries:** `/mnt/apps01/appdata/bin/`
- **Stack runtime:** `/mnt/apps01/appdata/{stack-name}/`
