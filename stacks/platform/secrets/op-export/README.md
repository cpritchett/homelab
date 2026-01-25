# 1Password Secrets Export Stack

Automated secrets export from 1Password for NAS-deployed stacks.

## Quick Start

1. **Prepare 1Password CLI helper script** (once per host):
   ```bash
   # Copy the export script from the repository to the host
   mkdir -p /mnt/apps01/scripts
   curl -o /mnt/apps01/scripts/op-export-stack-env.sh \
     https://raw.githubusercontent.com/cpritchett/homelab/main/stacks/scripts/op-export-stack-env.sh
   chmod +x /mnt/apps01/scripts/op-export-stack-env.sh
   ```

   **Why this is required:** Per [ADR-0022](../../docs/adr/ADR-0022-truenas-komodo-stacks.md), stacks must be deployable through Komodo without external dependencies. This helper script is shared infrastructure rather than stack-specific logic, and is therefore staged on the host once and reused by all stacks that need it.

2. **Create 1Password secrets directory** (once per host):
   ```bash
   mkdir -p /mnt/apps01/secrets/op
   ```

3. **Set up 1Password service account token**:
   - Create a service account in 1Password with access to the required vault
   - Store the token securely (e.g., in TrueNAS app secrets or use 1Password integration)
   - Set `OP_SERVICE_ACCOUNT_TOKEN` in the Komodo app configuration

4. **Configure environment** in Komodo:
   - Set `STACKS` to a space-separated list of stack names (e.g., `"authentik komodo caddy"`)
   - Set `OP_SERVICE_ACCOUNT_TOKEN` via secrets (do not commit to git)
   - Adjust `VAULT` and `DEST_ROOT` if needed (see `.env.example`)

5. **Run the export job**:
   - Start the app through Komodo or run manually: `docker compose up`
   - Exported secrets are written to `/mnt/apps01/secrets/<stack>/` as `.env` files
   - Files are tagged with the stack name for organization

## How It Works

The 1Password CLI (`op`) queries the specified vault for items tagged with `stack:<name>` and exports their fields as environment variables to `.env` files. These files are then mounted into dependent stacks.

### Stack Tagging Convention

To export secrets for a stack, tag the 1Password items with:
```
stack:<stack-name>
```

Example: Items tagged `stack:authentik` are exported when `STACKS` includes `authentik`.

### File Organization

```
/mnt/apps01/secrets/
├── op/
│   └── op.env                    # 1Password token (mounted from Komodo secret)
├── authentik/
│   ├── db.env                    # Exported from 1Password item tagged "stack:authentik"
│   ├── oidc.env
│   └── bootstrap.env
└── komodo/
    └── secrets.env               # Exported from 1Password items tagged "stack:komodo"
```

## Prerequisites

- TrueNAS host with `/mnt/apps01` mounted
- 1Password service account with vault access
- 1Password CLI helper script at `/mnt/apps01/scripts/op-export-stack-env.sh`
- Items in the vault tagged with `stack:<stack-name>`

## Environment Variables

See `.env.example` for configuration options:
- `OP_SERVICE_ACCOUNT_TOKEN` — 1Password service account token (required)
- `VAULT` — 1Password vault name (default: `homelab`)
- `DEST_ROOT` — Destination directory for exported files (default: `/mnt/apps01/secrets`)
- `STACKS` — Space-separated list of stacks to export secrets for

## Troubleshooting

### "cannot access vault" error
- Verify `OP_SERVICE_ACCOUNT_TOKEN` is set and valid
- Check that the service account has access to the specified vault in 1Password

### No items found warning
- Ensure 1Password items are tagged with `stack:<stack-name>`
- Verify the vault name matches the configured `VAULT`
- Run in verbose mode to see which items are being searched

### Exported files are empty
- Check that 1Password items have field labels and values
- Verify items end with `.env` suffix (e.g., `authentik.env`)
- Review script output for skipped items

## References

- [ADR-0022: Komodo-Managed NAS Stacks](../../docs/adr/ADR-0022-truenas-komodo-stacks.md) — Stack deployment model
- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
