# Stack Scripts

Helper scripts for managing NAS stacks deployed via Komodo.

## Scripts

### `op-create-stack-item.sh`

Creates 1Password items from `.env.example` files for use with the secrets export workflow.

**Purpose**: Bootstrap 1Password entries with the correct tags and structure so they can be exported by `op-export-stack-env.sh`.

**Usage**:
```bash
./op-create-stack-item.sh <path-to-.env.example> [item-title]
```

**Examples**:
```bash
# Create item for restic stack (single item)
./op-create-stack-item.sh ../platform/backups/restic/restic.env.example

# Create multiple items for authentik stack
./op-create-stack-item.sh ../platform/auth/authentik/authentik.env.example
./op-create-stack-item.sh ../platform/auth/authentik/postgres.env.example
```

**What it does**:
1. Parses variable names from the `.env.example` file
2. Automatically derives the stack name from the file path
3. Prompts interactively for real values (detects placeholders like `your-password` and requires input)
4. Creates a 1Password item in the `homelab` vault
5. Tags it with `stack:<name>` for export by `op-export-stack-env.sh`
6. Names the item appropriately (e.g., `restic.env`, `postgres.env`)

**Environment Variables**:
- `VAULT` — 1Password vault name (default: `homelab`)

**Requirements**:
- 1Password CLI (`op`) installed and signed in
- Access to the target vault

---

### `op-export-stack-env.sh`

Exports secrets from 1Password items to filesystem env files for stack deployment.

**Purpose**: Materialize secrets from 1Password into `/mnt/apps01/secrets/<stack>/` for use by Docker Compose stacks.

**Usage**:
```bash
./op-export-stack-env.sh <stack-name>
```

**Examples**:
```bash
# Export all items tagged "stack:authentik"
./op-export-stack-env.sh authentik

# Export all items tagged "stack:restic"
./op-export-stack-env.sh restic
```

**What it does**:
1. Queries 1Password vault for items tagged with `stack:<name>`
2. Extracts fields from each item
3. Writes them to `/mnt/apps01/secrets/<stack>/<item-title>` (e.g., `/mnt/apps01/secrets/authentik/postgres.env`)
4. Each item becomes a separate `.env` file

**Environment Variables**:
- `VAULT` — 1Password vault name (default: `homelab`)
- `DEST_ROOT` — Base directory for secrets (default: `/mnt/apps01/secrets`)

**Requirements**:
- 1Password CLI (`op`) with service account token or signed-in session
- Write access to `DEST_ROOT`

**Typically deployed via**: `stacks/platform/secrets/op-export` stack in Komodo

---

## Workflow

### Initial Setup (one-time per stack)

1. **Create 1Password items** from `.env.example` files:
   ```bash
   cd stacks/scripts
   ./op-create-stack-item.sh ../platform/backups/restic/restic.env.example
   
   # For stacks with multiple items (like authentik)
   ./op-create-stack-item.sh ../platform/auth/authentik/authentik.env.example
   ./op-create-stack-item.sh ../platform/auth/authentik/postgres.env.example
   ```

2. **Verify item** in 1Password:
   ```bash
   op item get restic.env --vault homelab
   ```

3. **Export secrets** to filesystem:
   ```bash
   ./op-export-stack-env.sh restic
   ```

4. **Deploy stack** via Komodo pointing to the exported env files

### Ongoing Updates

When stack secrets change:

1. **Update 1Password item** directly in 1Password UI or CLI
2. **Re-run export**:
   ```bash
   ./op-export-stack-env.sh <stack-name>
   ```
   Or trigger the `op-export` stack in Komodo

3. **Restart stack** in Komodo to pick up new values

---

## File Naming Convention

Each 1Password item should have its own `.env.example` file named after the item:

```
stacks/<category>/<stack-name>/
├── compose.yaml
├── <item-name>.env.example    # e.g., restic.env.example
└── README.md
```

For stacks requiring multiple 1Password items:

```
stacks/platform/auth/authentik/
├── compose.yaml
├── authentik.env.example      # Creates item: authentik.env
├── postgres.env.example       # Creates item: postgres.env
└── README.md
```

The script automatically derives the 1Password item name from the filename:
- `restic.env.example` → item name: `restic.env`
- `authentik.env.example` → item name: `authentik.env`
- `postgres.env.example` → item name: `postgres.env`

---

## Error Handling & Edge Cases

Both scripts handle common error scenarios gracefully:

### `op-create-stack-item.sh` Error Handling

**Item already exists in 1Password**:
- Script detects existing item and offers options:
  1. **Update** — Refresh all values, detects out-of-date fields
  2. **Skip** — Use existing item, no changes
  3. **Cancel** — Abort operation

**Missing or invalid values**:
- Placeholder detection identifies example values (e.g., `your-password`, `example.com`)
- Requires confirmation before committing values
- Shows all values with long values truncated for readability

**Out-of-date 1Password items**:
- Field-by-field comparison detects which values have changed
- Marks fields as "was out of date" when updating
- Counts successful updates and reports errors

**Vault access failures**:
- Clear error messages indicating authentication issues
- Suggests `op signin` if not authenticated

### `op-export-stack-env.sh` Error Handling

**Files already exist on disk**:
- Hash-based comparison detects if content is identical
- Shows "No changes" (up to date) when files match
- Updates files only when content differs
- Uses atomic writes (temp file → rename) to prevent corruption

**Items missing from 1Password**:
- Clear warning when no items found for stack
- Suggests checking item names, tags, and vault access
- Continues gracefully without exiting

**1Password item errors**:
- Per-item error tracking
- Continues processing remaining items
- Reports summary of successful/failed exports

**Vault access failures**:
- Validates vault access before starting export
- Provides troubleshooting suggestions
- Tests 1Password CLI authentication status

### Summary & Status Output

Both scripts provide clear, color-coded summary output:

**Export script example (no changes)**:
```
==> Exporting secrets for stack: authentik
    Vault: homelab
    Destination: /tmp/test-komodo-export/authentik

  ⊘ No changes: authentik-smtp.env (up to date)
  ⊘ No changes: authentik.env (up to date)
  ⊘ No changes: postgres.env (up to date)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Export Summary for Stack: authentik
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⊘ Unchanged:     3

✅ Successfully exported 3 secret file(s) for stack: authentik
   Destination: /mnt/apps01/secrets/authentik/
```

---

## Stack Tagging Convention

All 1Password items for stack secrets **must** be tagged with:
```
stack:<stack-name>
```

Where `<stack-name>` matches the directory name (e.g., `authentik`, `restic`, `uptime-kuma`).

Multiple items can share the same tag. For example, the `authentik` stack has:
- `authentik.env` (tagged `stack:authentik`)
- `postgres.env` (tagged `stack:authentik`)

Both are exported when you run `./op-export-stack-env.sh authentik`.

---

## Related Documentation

- [Komodo Secrets Management](../docs/KOMODO_SECRETS_MANAGEMENT.md) — Complete secrets procedures and Komodo integration
- [1Password Secrets Workflow](../../ops/runbooks/1password-secrets-workflow.md) — Detailed scenarios and troubleshooting
- [Platform Bootstrap Guide](../docs/PLATFORM_BOOTSTRAP.md) — Full platform setup procedure
- [ADR-0022: Komodo-Managed NAS Stacks](../../docs/adr/ADR-0022-truenas-komodo-stacks.md) — Architecture decision
- [Stacks Deployment Runbook](../../ops/runbooks/stacks-deployment.md) — Operational procedures
