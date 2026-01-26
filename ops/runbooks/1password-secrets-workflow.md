# 1Password Stack Secrets Workflow

**Quick reference for managing NAS stack secrets using 1Password and op-export/op-create scripts.**

See [Komodo Secrets Management](../../stacks/docs/KOMODO_SECRETS_MANAGEMENT.md) for comprehensive procedures, architecture, and troubleshooting.

## Quick Navigation

- **Creating secrets in 1Password** → Use op-create-stack-item.sh (see Scenarios 1-3 below)
- **Exporting secrets to disk** → Use op-export-stack-env.sh (see Export Scenarios below)
- **Komodo integration** → See [KOMODO_SECRETS_MANAGEMENT.md](../../stacks/docs/KOMODO_SECRETS_MANAGEMENT.md)
- **Full platform setup** → See [PLATFORM_BOOTSTRAP.md](../../stacks/docs/PLATFORM_BOOTSTRAP.md)

---

## Prerequisites

### Required Software
- **1Password CLI** (`op`) v2.32.0 or later
  ```bash
  op --version
  ```
- **jq** for JSON parsing
- **bash** 4.0+ (for associative arrays)

### Required Access
- **1Password vault**: `homelab` (or custom via `VAULT` environment variable)
- **Write access** to 1Password vault
- **Write access** to secrets destination directory (`/mnt/apps01/secrets/` by default)
- **Signed-in to 1Password CLI**:
  ```bash
  op signin
  ```

### Verify Setup
```bash
# Check 1Password authentication
op account get

# Check vault access
op vault list

# Test jq
echo '{}' | jq -e .
```

---

## Workflow: Creating Stack Secrets

### Scenario 1: New Stack (No 1Password Items Yet)

**Example: Setting up the `restic` backup stack**

1. **Navigate to scripts directory**:
   ```bash
   cd homelab/stacks/scripts
   ```

2. **Create the 1Password item** from the `.env.example` file:
   ```bash
   ./op-create-stack-item.sh ../platform/backups/restic/restic.env.example
   ```

3. **Script will**:
   - Parse `restic.env.example` and identify variables
   - Prompt for real values (detects placeholders like `your-password`)
   - Show review screen with all values
   - Request confirmation

4. **Review and confirm**:
   ```
   ==> Review values before committing
   
     RESTIC_REPOSITORY = s3:https://s3.example.com/backup
     RESTIC_PASSWORD = [your-secure-password]
     AWS_ACCESS_KEY_ID = [your-access-key]
     AWS_SECRET_ACCESS_KEY = [your-secret-key]
     RESTIC_HOSTNAME = nas01
     RESTIC_TAGS = home,backup
   
   Confirm and create item? (y/N) y
   ```

5. **Verify creation**:
   ```bash
   op item get restic.env --vault homelab
   ```

### Scenario 2: Multiple Items for One Stack

**Example: `authentik` stack requires separate items for app and database**

1. **Create app secrets**:
   ```bash
   ./op-create-stack-item.sh ../platform/auth/authentik/authentik.env.example
   ```

2. **Create database secrets**:
   ```bash
   ./op-create-stack-item.sh ../platform/auth/authentik/postgres.env.example
   ```

3. **Both items are tagged** `stack:authentik` automatically

4. **Verify**:
   ```bash
   op item list --vault homelab --tags stack:authentik
   ```

### Scenario 3: Item Already Exists

If you run the script and the item already exists:

```
⚠️  Warning: item 'restic.env' already exists in vault 'homelab'

Options:
  1) Update with new values from ../platform/backups/restic/restic.env.example
  2) Skip (use existing item as-is)
  3) Cancel
Choose (1-3): _
```

**Option 1 - Update**: Refresh values with field-by-field comparison:
- Shows which fields are "out of date" (changed since last update)
- Keeps unchanged values
- Reports count of updated fields

**Option 2 - Skip**: Use existing item without changes:
- Useful if you're just testing or need to abort
- Item remains untouched in 1Password

**Option 3 - Cancel**: Abort operation completely

---

## Workflow: Exporting Secrets to Filesystem

### Scenario 1: First Export (New Files)

**Export all secrets for the `authentik` stack**:

```bash
cd homelab/stacks/scripts
./op-export-stack-env.sh authentik
```

**Output**:
```
==> Exporting secrets for stack: authentik
    Vault: homelab
    Destination: /mnt/apps01/secrets/authentik

  ✓ Exported: authentik.env
  ✓ Exported: postgres.env
  ✓ Exported: authentik-smtp.env

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Export Summary for Stack: authentik
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ New exports:   3

✅ Successfully exported 3 secret file(s) for stack: authentik
   Destination: /mnt/apps01/secrets/authentik/
```

**Files created**:
- `/mnt/apps01/secrets/authentik/authentik.env`
- `/mnt/apps01/secrets/authentik/postgres.env`
- `/mnt/apps01/secrets/authentik/authentik-smtp.env`

### Scenario 2: Re-export (No Changes)

When you run export again and nothing has changed in 1Password:

```bash
./op-export-stack-env.sh authentik
```

**Output**:
```
==> Exporting secrets for stack: authentik
    Vault: homelab
    Destination: /mnt/apps01/secrets/authentik

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

**Note**: Files are not modified (hash-based detection prevents unnecessary writes)

### Scenario 3: Updated Secrets

After updating values in 1Password, re-run export:

```bash
./op-export-stack-env.sh authentik
```

**Output** (if 2 values changed):
```
==> Exporting secrets for stack: authentik
    Vault: homelab
    Destination: /mnt/apps01/secrets/authentik

  ✓ Updated: authentik.env
  ⊘ No changes: postgres.env (up to date)
  ⊘ No changes: authentik-smtp.env (up to date)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Export Summary for Stack: authentik
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Updated:       1
  ⊘ Unchanged:     2

✅ Successfully exported 3 secret file(s) for stack: authentik
   Destination: /mnt/apps01/secrets/authentik/
```

---

---

## Integration with Komodo

**All Komodo integration details are in [KOMODO_SECRETS_MANAGEMENT.md](../../stacks/docs/KOMODO_SECRETS_MANAGEMENT.md):**

Topics:
- Deploying op-export stack in Komodo
- Scheduling export runs (manual, daily, webhook)
- Using exported secrets in application stacks
- Rotating secrets and redeploying
- Advanced features (variable interpolation, permissioning, dependency management)
- Troubleshooting export failures

---

## Troubleshooting

### Error: "cannot access vault 'homelab'"

**Cause**: 1Password CLI not authenticated or vault name incorrect

**Solution**:
```bash
# Sign in to 1Password
op signin

# Verify vault access
op vault list

# Check current account
op account get
```

### Error: "no items found for stack 'restic'"

**Cause**: Items don't exist in 1Password yet OR not tagged with `stack:restic`

**Solution**:
```bash
# Create items using op-create-stack-item.sh
cd stacks/scripts
./op-create-stack-item.sh ../platform/backups/restic/restic.env.example

# Verify items and tags
op item list --vault homelab --tags stack:restic
```

### Error: "cannot create directory: /mnt/apps01/secrets/..."

**Cause**: Permission denied or path doesn't exist

**Solution**:
```bash
# Check permissions
ls -la /mnt/apps01/

# Create with proper permissions (if needed)
sudo mkdir -p /mnt/apps01/secrets
sudo chmod 755 /mnt/apps01/secrets

# Test with custom destination
DEST_ROOT=/tmp/test ./op-export-stack-env.sh authentik
```

### Exported file has wrong values

**Cause**: 1Password item hasn't been updated OR export used old secrets

**Solution**:
1. **Verify 1Password item**:
   ```bash
   op item get authentik.env --vault homelab
   ```

2. **Check exported file**:
   ```bash
   cat /mnt/apps01/secrets/authentik/authentik.env
   ```

3. **Update 1Password and re-export**:
   ```bash
   ./op-export-stack-env.sh authentik
   ```

### Script says "No changes" but values are wrong

**Cause**: File hash matches 1Password content, but both may be outdated

**Solution**:
1. Update the values in 1Password
2. Re-run export script (will show "Updated" status)
3. Verify new values in exported file

---

## Complete End-to-End Example

Setting up a new `caddy` ingress stack:

### Step 1: Create 1Password item

```bash
cd homelab/stacks/scripts
./op-create-stack-item.sh ../platform/ingress/caddy/caddy.env.example
```

Prompts:
```
==> Parsing ../platform/ingress/caddy/caddy.env.example
Found 3 variables

==> Enter values for each variable
CADDY_EMAIL [example@example.com]: admin@hypyr.space
CADDY_DOMAIN [caddy.example.com]: caddy.hypyr.space
ACME_PROVIDER [letsencrypt]: letsencrypt

==> Review values before committing
  CADDY_EMAIL = admin@hypyr.space
  CADDY_DOMAIN = caddy.hypyr.space
  ACME_PROVIDER = letsencrypt

Confirm and create item? (y/N) y

✓ Created item 'caddy.env'

==> Success!
The item 'caddy.env' is now available in vault 'homelab' with tag 'stack:caddy'.

To export this to the host, run op-export-stack-env.sh:
  ./op-export-stack-env.sh caddy
```

### Step 2: Export secrets

```bash
./op-export-stack-env.sh caddy
```

Output:
```
==> Exporting secrets for stack: caddy
    Vault: homelab
    Destination: /mnt/apps01/secrets/caddy

  ✓ Exported: caddy.env

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Export Summary for Stack: caddy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ New exports:   1

✅ Successfully exported 1 secret file(s) for stack: caddy
   Destination: /mnt/apps01/secrets/caddy/
```

### Step 3: Deploy via Komodo

1. Open Komodo dashboard at `https://komodo.in.hypyr.space`
2. Navigate to `stacks/platform/ingress/caddy`
3. Click "Deploy"
4. Komodo pulls values from `/mnt/apps01/secrets/caddy/caddy.env`
5. Container starts with proper environment variables

### Step 4: Update secrets (if needed)

Later, if you need to change CADDY_DOMAIN:

```bash
# Update in 1Password directly via UI or:
op item edit caddy.env --vault homelab CADDY_DOMAIN=caddy.new.hypyr.space

# Export updated values
./op-export-stack-env.sh caddy

# Redeploy stack in Komodo
```

---

## Best Practices

1. **Always review values before confirming** in op-create-stack-item.sh
2. **Use placeholder values** in `.env.example` files (e.g., `your-password`, `example.com`)
3. **Run export script regularly** to keep filesystem in sync with 1Password
4. **Verify exported files** after first export to catch configuration issues early
5. **Keep `.env.example` files updated** when adding new required variables
6. **Use separate 1Password items** for each component (app vs database configs)
7. **Monitor export logs** for error messages indicating permission or vault issues

---

## Related Documentation

- [Stack Scripts Reference](./stacks-scripts.md) — op-create and op-export script documentation
- [Platform Bootstrap Guide](../../stacks/docs/PLATFORM_BOOTSTRAP.md) — Full platform setup
- [ADR-0022: Komodo-Managed NAS Stacks](../../docs/adr/ADR-0022-truenas-komodo-stacks.md) — Architecture decision
- [Stacks Deployment Procedures](../../docs/governance/procedures.md) — Operational workflows

---

## Quick Reference

| Task | Command |
|------|---------|
| Create new 1Password item | `./op-create-stack-item.sh <path-to-.env.example>` |
| Export secrets for stack | `./op-export-stack-env.sh <stack-name>` |
| List items for stack | `op item list --vault homelab --tags stack:<stack>` |
| View single item | `op item get <item-name>.env --vault homelab` |
| Update item value | `op item edit <item-name>.env --vault homelab VAR=value` |
| Verify 1Password auth | `op account get` |
| View exported secrets | `cat /mnt/apps01/secrets/<stack>/<item>.env` |

---

**Last Updated**: January 2026  
**Version**: 1.0
