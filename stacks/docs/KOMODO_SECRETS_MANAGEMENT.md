# Komodo Secrets Management

**Comprehensive guide for managing platform stack secrets via 1Password and Komodo.**

## Overview

This document covers the complete secrets workflow in a Komodo-managed platform:

1. Define secrets in 1Password
2. Export secrets to filesystem via op-export stack
3. Deploy application stacks that consume exported secrets
4. Rotate secrets and redeploy

---

## Architecture

The secrets flow is strictly ordered:

```
1Password vault (source of truth)
         ↓
    op-export stack (Komodo)
         ↓
/mnt/apps01/secrets/<stack>/*.env (host filesystem)
         ↓
Application stacks (authentik, restic, etc.)
```

**Key principle:** No application stack can deploy successfully without its secrets exported to disk.

---

## Prerequisites

### On TrueNAS host
- 1Password CLI (`op`) v2.32.0+
- Signed-in to 1Password: `op account get`
- Access to `homelab` vault
- Write access to `/mnt/apps01/secrets/`

### In Komodo
- Git provider configured (GitHub integration)
- OP_SERVICE_ACCOUNT_TOKEN stored as a secret
- op-export stack deployed and functional

---

## Creating Secrets in 1Password

See [1Password Secrets Workflow](../../ops/runbooks/1password-secrets-workflow.md#workflow-creating-stack-secrets) for detailed steps on:
- Creating items from `.env.example` files
- Managing multiple items per stack
- Handling existing items
- Using the op-create-stack-item.sh script

**Quick reference:**
```bash
cd stacks/scripts
./op-create-stack-item.sh ../platform/auth/authentik/authentik.env.example
./op-create-stack-item.sh ../platform/auth/authentik/postgres.env.example
```

---

## Deploying the op-export Stack

The op-export stack is a platform service that materializes secrets from 1Password to disk.

### Step 1: Store the 1Password token as a Komodo Variable

Store the token as a global variable in Komodo so it can be referenced by the op-export stack's compose file.

**In Komodo web UI:**

1. Click **Settings** (gear icon, typically top-right)
2. Navigate to **Variables & Secrets** section
3. Click **Add Variable** (or **Add Secret** if encrypting preferred)
4. Fill in:
   - **Name**: `OP_SERVICE_ACCOUNT_TOKEN`
   - **Value**: Your 1Password service account token (from 1Password account settings)
5. Click **Save**

**Note:** You can use either Variable (plain text) or Secret (encrypted). Use Secret if you want the value hidden from logs and database lookups.

**Bootstrap note:** This is a chicken-and-egg problem for the first deployment. Komodo variables are stored in Komodo's database, but you need the token to export the first secrets. Options:
1. **Temporary hardcode** in compose.yaml for first run, then switch to interpolation after (see Step 2 alternative below)
2. **Manual CLI export** before deploying stack (run op-export-stack-env.sh manually on host with token in environment)
3. **Secret in .env file** (traditional approach - store op.env in 1Password, export it first, then reference)

### Step 2: Update the op-export compose.yaml

The environment variables are configured **in the Git repo's compose file**, not in Komodo UI.

**Edit `stacks/platform/secrets/op-export/compose.yaml`:**

```yaml
services:
  op-export:
    image: 1password/op:2
    restart: "no"
    environment:
      OP_SERVICE_ACCOUNT_TOKEN: [[OP_SERVICE_ACCOUNT_TOKEN]]  # Komodo interpolates this
      VAULT: homelab
      DEST_ROOT: /mnt/apps01/secrets
      STACKS: authentik restic uptime-kuma
    volumes:
      - type: bind
        source: /mnt/apps01
        target: /mnt/apps01
    working_dir: /mnt/apps01
    entrypoint: ["/bin/sh","-lc"]
    command: >
      apk add --no-cache jq >/dev/null &&
      for s in $STACKS; do
        /mnt/apps01/scripts/op-export-stack-env.sh "$s";
      done
```

**For first-time bootstrap only:**

If this is your first deployment and the Komodo variable hasn't been used yet, you can temporarily hardcode the token:

```yaml
environment:
  OP_SERVICE_ACCOUNT_TOKEN: "your-actual-token-here"  # TEMPORARY - replace with [[OP_SERVICE_ACCOUNT_TOKEN]] after first run
  VAULT: homelab
  DEST_ROOT: /mnt/apps01/secrets
  STACKS: authentik restic uptime-kuma
```

Then after the first successful export:
1. Update back to `[[OP_SERVICE_ACCOUNT_TOKEN]]`
2. Commit to Git
3. Redeploy (Komodo will now interpolate from the stored variable)

Alternatively, manually export secrets first on the host without Komodo, then deploy the stack through Komodo for ongoing management.

### Step 3: Deploy op-export stack in Komodo

**In Komodo web UI:**

1. Click **Stacks** (or **Add Stack** if no stacks exist yet)
2. Click **Add Stack** → **From Git**
3. Configure:
   - **Stack name**: `op-export`
   - **Repository**: Select your homelab repo
   - **Branch**: `main` (or your active branch)
   - **Path**: `stacks/platform/secrets/op-export`
   - **Compose file**: `compose.yaml`

4. **Click Deploy**
   - Komodo pulls the compose file from Git
   - Interpolates `[[OP_SERVICE_ACCOUNT_TOKEN]]` with the variable value
   - Runs the op-export container
   - Outputs results to logs

**Note:** Komodo will show export results in logs. Look for:
```
✓ Exported: authentik.env
✓ Exported: postgres.env
```

### Step 4: Verify export success

**In Komodo UI:**
- Open the op-export stack
- Check the **Logs** tab
- Look for lines showing successful exports

**On TrueNAS host:**
```bash
ls -la /mnt/apps01/secrets/authentik/
head -5 /mnt/apps01/secrets/authentik/authentik.env
```

If files don't exist or are empty, check:
1. 1Password items exist with correct tags: `stack:authentik`, `stack:restic`, etc.
2. `STACKS` variable in compose.yaml includes all stacks
3. OP_SERVICE_ACCOUNT_TOKEN is correct and not expired

---

## Scheduling op-export Runs

Choose one approach based on your operational needs.

### Option 1: Manual Export (One-Time or Ad-Hoc)

**When to use:** First-time setup, testing, or irregular secret updates

1. In Komodo, open op-export stack
2. Click **Start** or **Redeploy**
3. Monitor logs until completion
4. Proceed to deploy dependent stacks

### Option 2: Scheduled Daily Export (Recommended)

**When to use:** Regular platform operations, ensures secrets stay fresh

Create a Komodo **Procedure** to run op-export automatically:

**Step 1: In Komodo UI**
1. Navigate to **Procedures** → **Add Procedure**
2. Create with this configuration:

**Step 2: TOML configuration**
```toml
[[procedure]]
name = "Daily Secrets Export"
description = "Export all stack secrets from 1Password at scheduled time"
tags = ["platform", "system"]
config.schedule = "Every day at 02:00"

[[procedure.config.stage]]
name = "Export Secrets"
executions = [
  { execution.type = "DeployStack", execution.params.stack = "op-export", enabled = true }
]
```

3. Save and enable

**Benefit:** Ensures secrets are always current without manual intervention.

### Option 3: Export on Git Webhook (For Development)

**When to use:** Rapid iteration during development, testing new `.env.example` files

1. Configure webhook in GitHub to trigger on commits to `stacks/platform/secrets/op-export/`
2. Create a Komodo **Procedure** that runs on webhook:
   ```toml
   [[procedure]]
   name = "Export Secrets on Push"
   config.webhook_path = "export-secrets"
   
   [[procedure.config.stage]]
   name = "Export"
   executions = [
     { execution.type = "DeployStack", execution.params.stack = "op-export", enabled = true }
   ]
   ```
3. Komodo automatically exports when you push changes to the `.env.example` files

---

## Using Exported Secrets in Application Stacks

Once secrets are exported, application stacks reference them via `env_file`:

```yaml
services:
  authentik:
    image: ghcr.io/goauthentik/server:latest
    env_file:
      - /mnt/apps01/secrets/authentik/authentik.env
      - /mnt/apps01/secrets/authentik/postgres.env
```

**Configuration in Komodo:**
1. Deploy the application stack (e.g., authentik)
2. Komodo passes the env file to docker compose
3. Container reads environment variables at startup

**Best practice:** Mount the entire secrets file, don't duplicate values in Komodo environment variables.

---

## Updating and Rotating Secrets

### Simple Update (Change One Value)

1. **Update in 1Password**:
   ```bash
   op item edit authentik.env --vault homelab AUTHENTIK_SECRET_KEY=new-key
   ```

2. **Trigger export** (manual or wait for scheduled):
   - Manual: Komodo UI → op-export → **Start**
   - Scheduled: Wait for next scheduled run

3. **Verify export**:
   - Check Komodo logs for "Updated: authentik.env"
   - Spot-check file: `cat /mnt/apps01/secrets/authentik/authentik.env`

4. **Redeploy dependent stack**:
   - Komodo UI → authentik → **Redeploy**
   - Container restarts with new environment

### Mass Rotation (Multiple Stacks)

1. Update multiple items in 1Password
2. Update the `STACKS` variable in op-export config to include all affected stacks
3. Trigger export (all stacks' secrets get updated)
4. Redeploy all affected stacks in dependency order

---

## Troubleshooting

### Export fails: "OP_SERVICE_ACCOUNT_TOKEN invalid"

1. Verify token in Komodo Settings
2. Check token is still valid in 1Password (may have expired)
3. Update the token and redeploy op-export

### Export fails: "vault 'homelab' not found"

1. Verify you're signed into the correct 1Password account: `op account get`
2. Check vault name matches your setup: `op vault list`
3. Update `VAULT` environment variable in op-export stack config

### Export succeeds but files are empty

1. Verify 1Password items exist: `op item list --vault homelab --tags stack:authentik`
2. Verify items have correct tag: `stack:<stack-name>`
3. Manually test export from host:
   ```bash
   ssh truenas-host
   cd stacks/scripts
   export OP_SERVICE_ACCOUNT_TOKEN="your-token"
   ./op-export-stack-env.sh authentik
   ```

### Application stack won't start: "env file not found"

1. Verify op-export ran successfully (check Komodo logs)
2. Verify file exists: `ls -la /mnt/apps01/secrets/<stack>/`
3. Check file permissions: `ls -la /mnt/apps01/secrets/`
4. If missing, manually run op-export or check 1Password items exist

### File permissions denied

1. Check destination ownership: `ls -la /mnt/apps01/`
2. Fix permissions:
   ```bash
   sudo chown -R root:root /mnt/apps01/secrets/
   sudo chmod 755 /mnt/apps01/secrets/
   ```

---

## Advanced: Komodo Features for Secrets

### Variable Interpolation

Use global variables across stacks:

```yaml
# In stack config
environment = """
DATABASE_PASSWORD = [[DB_PASSWORD_GLOBAL]]
AUTHENTIK_SECRET = [[SHARED_SECRET]]
"""
```

Define these once in Komodo **Settings** and reference in multiple stacks.

### Secret Encryption

Komodo stores secrets encrypted in its database:
- Added via UI are never visible in logs
- Supports rotation via UI
- Can be updated without redeploying compose

### Permissioning for Secrets

Control who can deploy op-export or view secrets:

```toml
[[user_group]]
name = "platform-ops"

# Can deploy all stacks
all.Stack = { level = "Execute" }

# Can edit op-export configuration (and see token)
permissions = [
  { target.type = "Stack", target.id = "op-export", level = "Write" }
]
```

---

## Dependency Management

### Enforcing Deploy Order (with Resource Syncs)

For advanced setups using TOML-based deployment, enforce dependencies:

```toml
[[stack]]
name = "authentik"
after = ["op-export"]  # authentik only deploys AFTER op-export succeeds
deploy = true

[stack.config]
# authentik configuration...
```

When using **Resource Sync**, Komodo enforces:
1. op-export runs and completes
2. Then authentik (and other dependent stacks) deploy

### Manual Dependency Management

Without ResourceSync, enforce order yourself:
1. Deploy op-export first → verify success
2. Deploy authentik, restic, uptime-kuma (in any order)

---

## Related Documentation

- [1Password Secrets Workflow](../../ops/runbooks/1password-secrets-workflow.md) — Script usage and scenarios
- [Platform Bootstrap Guide](./PLATFORM_BOOTSTRAP.md) — Full platform setup order
- [Komodo Official Documentation](https://komo.do/docs/intro)
- [Komodo Stacks Guide](https://komo.do/docs/resources/docker-compose)
- [ADR-0022: Komodo-Managed NAS Stacks](../../docs/adr/ADR-0022-truenas-komodo-stacks.md)

---

**Last Updated:** January 2026
