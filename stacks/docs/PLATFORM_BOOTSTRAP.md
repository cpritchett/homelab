# PLATFORM_BOOTSTRAP.md

## Purpose

Bootstrap the TrueNAS + Komodo "platform services" layer (non-Kubernetes) that supports all application stacks.

Platform services included:
- Caddy (already running)
- 1Password -> env materializer (op-export job)
- Authentik (SSO/MFA)
- Uptime Kuma (basic monitoring)
- Restic -> S3 (backups)

This is intentionally small. Everything else belongs in application stacks.

## Assumptions

- TrueNAS SCALE host
- Komodo manages Compose stacks
- Caddy is already deployed and attached to the external Docker network `proxy_network`
- DNS works for `*.in.hypyr.space`
- `/mnt/apps01` is fast storage, `/mnt/data01` is spinning rust
- Secrets are stored in 1Password and materialized to `/mnt/apps01/secrets/<stack>/*.env`

## Repo conventions (this repo)

Your repo contains Kubernetes homelab content at the root. Docker/Komodo stacks live under:

- `stacks/` (this document assumes this is the base)
- Each stack uses `compose.yaml`

Relevant layout:

- `stacks/platform/secrets/op-export/compose.yaml`
- `stacks/platform/auth/authentik/compose.yaml`
- `stacks/platform/observability/uptime-kuma/compose.yaml`
- `stacks/platform/backups/restic/compose.yaml`
- `stacks/scripts/op-export-stack-env.sh`
- `stacks/scripts/restic/run.sh`
- `stacks/docs/PLATFORM_BOOTSTRAP.md`
- `stacks/docs/RESTORE_RUNBOOK.md`
- `stacks/docs/CADDY_FORWARD_AUTH_LABELS.md`

## Step 0: Host directories (one-time)

Run on the TrueNAS host:

```
mkdir -p /mnt/apps01/appdata
mkdir -p /mnt/apps01/appdata/proxy
mkdir -p /mnt/apps01/secrets
mkdir -p /mnt/apps01/appdata/restic/cache

mkdir -p /mnt/apps01/appdata/uptime-kuma

mkdir -p /mnt/apps01/appdata/authentik
mkdir -p /mnt/apps01/appdata/authentik/media
mkdir -p /mnt/apps01/appdata/authentik/custom-templates

mkdir -p /mnt/data01/appdata/authentik
mkdir -p /mnt/data01/appdata/authentik/postgres
mkdir -p /mnt/data01/appdata/authentik/redis
```

Notes:
- Postgres on rust (`/mnt/data01`) is fine and matches your preference.
- Redis can be ephemeral; persistence is optional. If you want persistence, mount it (see Authentik compose notes).
- Restic scripts (`run.sh`, `excludes.txt`) are bundled in the stack directory; Komodo handles syncing them automatically.

## Step 0.5: Komodo initial setup (one-time)

Komodo is a TrueNAS SCALE app that manages Docker Compose stacks from Git repositories. This section assumes Komodo has been installed as a standalone TrueNAS app but has not been configured yet.

### What is Komodo?

Komodo is a web application designed to provide structure for managing servers, builds, deployments, and automated procedures. It uses Docker as the container engine and follows an opinionated design.

**Architecture:**
- **Komodo Core**: Web server hosting the Core API and browser UI. All user interaction flows through Core.
- **Komodo Periphery**: Small stateless web server running on connected servers. Exposes an API called by Core to perform actions, get system usage, and container status/logs. Has an address whitelist to limit allowed IPs.

**Key capabilities:**
- Deploy docker compose stacks with files defined in UI, local filesystem, or git repos
- Auto-deploy on git push via webhooks
- Manage environment variables with global variable/secret interpolation
- Track all actions and who performed them
- No limits on number of connected servers or API usage

### Install Komodo (if not already running)

1. In TrueNAS SCALE UI, go to **Apps** → **Discover Apps**
2. Search for "Komodo" and install it
3. Use default settings or customize as needed (e.g., WebUI port, storage paths)
4. Wait for the app to start
5. Ensure Komodo is accessible via Caddy at `https://komodo.in.hypyr.space`

### Initial Komodo configuration

1. **Access Komodo UI** at `https://komodo.in.hypyr.space` (or direct via `http://<truenas-ip>:<port>` if DNS/Caddy not yet configured)
2. **Complete first-time setup**:
   - Create admin user and password
   - Set server name/description (e.g., "homelab-nas")
   - Configure any initial settings

3. **Add GitHub integration** (required to deploy stacks from this repo):
   - Navigate to **Settings** → **Git Providers** (or equivalent section)
   - Add a new GitHub provider:
     - **Provider type**: GitHub
     - **Repository URL**: `https://github.com/cpritchett/homelab`
     - **Branch**: `main` (or your active branch)
     - **Authentication**: 
       - For public repos: No auth required
       - For private repos: Create a GitHub Personal Access Token (PAT) with `repo` scope and add it here
   - Save the configuration
   - **Note**: Komodo has an in-built token management system to give resources access to git repos and docker registries. You can manage these credentials in the UI or config file. All resources that depend on git repos/registries can use these credentials to access private repos.

4. **Verify Git integration**:
   - Komodo should be able to browse the repository
   - Confirm you can see the `stacks/` directory structure

### Create prerequisite Docker resources

Before deploying any stacks, ensure shared resources exist:

```bash
# SSH into TrueNAS host and run:
docker network create proxy_network
```

This external network is required for Caddy (proxy) and all apps that route through it.

### Komodo deployment workflow (overview)

Each platform stack will be deployed using this pattern:

1. In Komodo UI, click **Add Stack** (or equivalent)
2. Select **From Git**
3. Configure stack source:
   - **Repository**: Select your homelab repo (from Step 0.5)
   - **Path**: Specify the stack directory (e.g., `stacks/platform/secrets/op-export`)
   - **Compose file**: `compose.yaml` (or `compose.yml`, depending on stack)
   - **Compose file definition methods**: Komodo supports 3 ways:
     1. Write files in UI - Komodo writes them to host at deploy-time
     2. Store files anywhere on host - Komodo runs compose commands on existing files
     3. Store in git repo - Komodo clones repo on host to deploy (recommended)
   - **Multiple compose files**: Supports composing multiple files using `docker compose -f ... -f ...`
4. **Environment variables & secrets**:
   - Review the stack's `*.env.example` files (in the repo) for required variables
   - Each `<item-name>.env.example` file corresponds to one 1Password item
   - Add each required variable in Komodo's **Environment** or **Secrets** section
   - For sensitive values (passwords, tokens), use the **Secrets** section
   - **How it works**: Komodo writes variables to a ".env" file on the host at deploy-time and passes it to docker compose using the `--env-file` flag
   - **Variable interpolation**: Supports global variables and secrets - define once and share across environments using `[[VARIABLE_NAME]]` syntax
5. **Deploy**: Click deploy/start
6. **Verify**: Check logs and ensure containers start successfully

### Important notes

- **Do not commit secrets to Git**: Use Komodo's secrets management instead
- **Stack dependencies**: Some stacks require others to be running first (e.g., Authentik requires proxy network and Caddy)
- **Updates**: When you update a stack's `compose.yaml` in Git, redeploy from Komodo to pick up changes
- **Break-glass access**: Komodo is accessible at `https://komodo.in.hypyr.space`. Keep direct IP access available (without Authentik auth) until Authentik is fully operational and tested
- **Backup Komodo config**: Komodo's own configuration (stack definitions, env vars) should be backed up separately

### Webhooks for automatic deployment

Komodo can automatically redeploy stacks when you push changes to Git:

1. **Enable webhooks** in your git provider (GitHub, GitLab, etc.)
2. **Configure webhook URL**: Point to your Komodo instance's webhook endpoint
3. **Set trigger events**: Typically `push` events on the configured branch
4. **Benefit**: Redeploying becomes as easy as `git push` - no manual intervention needed

**Why use webhooks?**
- All your files across all servers are available locally to edit in your favorite text editor
- All changes are tracked in Git and can be reverted
- Enables GitOps workflows and automation
- Changes propagate automatically across environments

### Auto-update configuration

Komodo supports automatic updates for stacks and deployments:

**Poll for Updates mode:**
- Komodo checks for newer images at the same tag (e.g., `:latest`)
- Sends alerts when updates are available
- Shows update indicator in UI
- Requires manual deployment

**Auto Update mode:**
- Automatically redeploys services when newer images are available
- Only updates services with changes (by default)
- Sends alerts when auto-updates occur
- Works with rolling tags like `:latest`

**Global Auto Update:**
- System procedure that runs daily (default: 03:00)
- Processes all resources with poll/auto-update enabled
- Can be customized or integrated with other procedures (e.g., run after backups)
- Configuration:

```toml
[[procedure]]
name = "Global Auto Update"
description = "Pulls and auto updates Stacks and Deployments using 'poll_for_updates' or 'auto_update'."
tags = ["system"]
config.schedule = "Every day at 03:00"

[[procedure.config.stage]]
name = "Stage 1"
enabled = true
executions = [
  { execution.type = "GlobalAutoUpdate", execution.params = {}, enabled = true }
]
```

**Note**: For git-sourced stacks with specific image tags, consider using [Renovate](https://github.com/renovatebot/renovate) to automatically update image tags in your compose files.

## Step 1: 1Password items (source of truth)

All items live in the `homelab` vault.

**See [Komodo Secrets Management § Creating Secrets](./KOMODO_SECRETS_MANAGEMENT.md#creating-secrets-in-1password) for:**
- Step-by-step item creation
- Handling multiple items per stack
- Using op-create-stack-item.sh
- Detailed scenarios and examples

**Quick reference:**
```bash
cd stacks/scripts
./op-create-stack-item.sh ../platform/auth/authentik/authentik.env.example
./op-create-stack-item.sh ../platform/auth/authentik/postgres.env.example
```

Items are automatically tagged with `stack:<stack-name>` for export.

## Step 2: Materialize env files (op-export job)

**See [Komodo Secrets Management](./KOMODO_SECRETS_MANAGEMENT.md) for complete procedures:**
- Creating 1Password items for stacks
- Deploying op-export stack in Komodo
- Scheduling/automating export runs
- Updating secrets and redeploying

**Quick summary:**
1. Create 1Password items using op-create-stack-item.sh
2. Deploy op-export stack in Komodo with OP_SERVICE_ACCOUNT_TOKEN secret
3. Run export manually or schedule daily
4. Verify secrets exported to `/mnt/apps01/secrets/<stack>/`
5. Proceed to deploy application stacks

## Step 3: Deploy Authentik (do not gate anything yet)

**In Komodo**, deploy the Authentik stack:

**Stack path**: `stacks/platform/auth/authentik`

**Required secrets** (sourced from `/mnt/apps01/secrets/authentik/` after op-export runs):
- Mount or reference the exported env files, or manually populate from 1Password
- See 1Password item `authentik.env` and `postgres.env` for required values

**Deployment**:
1. Follow Komodo deployment workflow from Step 0.5
2. Ensure the proxy network exists and Caddy is running
3. Deploy the stack

Verify:
- `https://auth.in.hypyr.space` loads through Caddy
- Bootstrap login works
- Create a second admin user immediately
- Enable MFA for both admin users
- Create an "Operators" group (or similar) and only grant admin roles to that group

Do not protect Komodo until Authentik is stable and you have two admin identities with MFA.

## Step 4: Deploy observability (Uptime Kuma)

**In Komodo**, deploy the Uptime Kuma stack:

**Stack path**: `stacks/platform/observability/uptime-kuma`

**Configuration**:
- No environment variables required (all configuration via web UI)
- Follow Komodo deployment workflow from Step 0.5

Verify:
- `https://status.in.hypyr.space` loads
- Add monitors for:
  - auth.in.hypyr.space
  - komodo.in.hypyr.space
  - barbary.in.hypyr.space
  - any other "tier-0" UIs

## Step 5: Deploy backups (Restic) - run manually first

**In Komodo**, deploy the Restic stack:

**Stack path**: `stacks/platform/backups/restic`

**Required secrets** (sourced from `/mnt/apps01/secrets/restic/restic.env`):
- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ENDPOINT`
- `AWS_DEFAULT_REGION`

**Deployment**:
1. Follow Komodo deployment workflow from Step 0.5
2. Mount or reference the exported restic.env file

Run manually first:
- RESTIC_TASK=backup
- RESTIC_TASK=snapshots
- RESTIC_TASK=check

Confirm snapshots exist in your S3 backend (SeaweedFS).

Only after that should you schedule:
- Daily: backup
- Weekly: prune
- Monthly: check

## Step 6: Protect apps with Authentik (per-app opt-in)

Use forward-auth in Caddy only on apps you choose.

Start with:
- komodo.in.hypyr.space

Process:
1) Create Authentik Proxy Provider for the app
2) Deploy the outpost (proxy outpost)
3) Add Caddy forward-auth labels to the app route (see stacks/docs/CADDY_FORWARD_AUTH_LABELS.md)
4) Confirm you can still reach the app via direct LAN address as a break-glass path (or keep a separate non-auth hostname)

## "What goes top level" rule

Top level (platform) should be:
- ingress
- auth
- secrets materialization
- monitoring
- backups

Everything else is an app stack.

---

## Komodo Tips & Troubleshooting

### Updating a stack

When you update a stack's `compose.yaml` or scripts in Git:

**Manual update workflow:**
1. Commit and push changes to the homelab repo
2. In Komodo, navigate to the stack
3. Click **Update/Redeploy** to pull latest changes from Git
4. Review any new environment variables in the stack's `*.env.example` files
5. Restart the stack

**Automatic update with webhook (recommended):**
1. Configure a webhook in your git provider (see "Webhooks for automatic deployment" above)
2. Commit and push changes to the homelab repo
3. Komodo automatically detects the push and redeploys the stack
4. Monitor deployment in Komodo UI or check alerts if configured

**Importing existing compose projects:**
If you have a compose project already running on the host:
1. Create the Stack in Komodo and configure it to access the compose files
2. Find the project name by running `docker compose ls` on the host
3. By default, Komodo assumes Stack name = compose project name
4. If different, configure custom "Project Name" in the stack config
5. Komodo will then pick up the running project and allow management through the UI

### Viewing logs

- In Komodo UI: Navigate to stack → **Logs** tab
- Via Docker CLI on host: `docker logs <container-name> --tail=200`

### Common issues

**Stack won't start - "network not found"**:
- Ensure `proxy_network` exists: `docker network create proxy_network`
- Check compose file for correct network references

**Container can't read secrets/env files**:
- Verify files exist in `/mnt/apps01/secrets/<stack>/`
- Check file permissions: `ls -la /mnt/apps01/secrets/<stack>/`
- Ensure op-export job ran successfully

**Komodo can't access GitHub repo**:
- For private repos: Verify GitHub PAT has `repo` scope and is still valid
- Check network connectivity from TrueNAS host: `ping github.com`

**Stack deployed but not accessible via domain**:
- Verify DNS resolves: `nslookup <app>.in.hypyr.space`
- Check Caddy is running and proxy_network is attached
- Review Caddy labels in the compose file
- Check Caddy logs for routing errors

### Accessing Komodo safely

- **Primary access**: `https://komodo.in.hypyr.space` (via Caddy)
- **Before Authentik is configured**: Access Komodo directly - no auth required
- **After Authentik is configured**: Can add forward-auth to `komodo.in.hypyr.space` (see Step 6)
- **Always maintain break-glass access**: Keep direct IP access (`http://<truenas-ip>:<port>`) available for recovery scenarios when Caddy or Authentik are down

### Stack directory structure reference

Each stack follows this pattern:
```
stacks/<category>/<stack-name>/
├── compose.yaml                  # Docker Compose definition
├── <item-name>.env.example       # Template for 1Password item (e.g., restic.env.example)
├── <another-item>.env.example    # Additional items if needed (e.g., postgres.env.example)
└── README.md                     # Stack-specific documentation (optional)
```

Each `<item-name>.env.example` file maps to one 1Password item with the same name.

### Advanced Komodo features

#### Resource Syncs (Infrastructure as Code)

Komodo can manage all resources declaratively using TOML files in Git repos:

**What it does:**
- Creates, updates, deletes, and deploys resources by diffing against existing state
- Applies updates based on detected diffs
- Polls files for changes and alerts about pending changes
- Can execute syncs automatically via webhook or manually via UI

**Organization:**
- Spread declarations across multiple files
- Use folder nesting for organization
- Create multiple ResourceSyncs with tag filters for per-project management
- Each sync is handled independently

**Example Stack declaration in TOML:**
```toml
[[stack]]
name = "authentik"
description = "SSO and authentication platform"
deploy = true
tags = ["platform", "auth"]

[stack.config]
server_id = "truenas-01"
file_paths = ["compose.yaml"]
git_provider = "github.com"
git_account = "cpritchett"
repo = "cpritchett/homelab"
branch = "main"
repo_path = "stacks/platform/auth/authentik"

# Environment variables
environment = """
AUTHENTIK_SECRET_KEY = [[AUTHENTIK_SECRET_KEY]]
AUTHENTIK_HOST = https://auth.in.hypyr.space
"""
```

**Stack dependencies with `after`:**
```toml
[[stack]]
name = "app-stack"
after = ["authentik", "postgres"]  # Deploy only after these are running
deploy = true
```

**Benefits:**
- GitOps workflow for all infrastructure
- Changes are version controlled
- Can review diffs before applying
- Supports dependency ordering
- Enables programmatic infrastructure management

**Managed Mode:**
For single-file syncs, enable "Managed Mode" to allow Core to write UI updates back to the file, creating commits to your git repository.

#### Procedures and Actions

**Procedures**: Compose multiple actions on resources (like `RunBuild`, `DeployStack`) and execute them:
- Run on button push or via webhook
- Support parallel "stages" that run sequentially
- Enable complex orchestration workflows

**Actions**: Write scripts in TypeScript calling the Komodo API:
- Pre-initialized Komodo client (no API keys needed)
- Type-aware editor with suggestions and docs
- Can orchestrate any Komodo operation programmatically

#### Permissioning system

Komodo has granular permissioning for multi-user environments:
- User Groups with configurable permissions
- Resource-level access control (Read, Write, Execute)
- Specific permission types per resource (e.g., Server: Attach, Logs, Terminal)
- User sign-on via username/password or OAuth (Github, Google)
- Perfect for teams with different roles (developers, operators, administrators)

#### Core API and programmatic access

Komodo exposes powerful REST and WebSocket APIs:
- [Rust crate](https://crates.io/crates/komodo_client)
- [NPM package](https://www.npmjs.com/package/komodo_client)
- Can be used with any language that makes REST requests
- Enables infrastructure automation and custom tooling

Related documentation:
- [Komodo Secrets Management](./KOMODO_SECRETS_MANAGEMENT.md) — Complete secrets procedures
- [1Password Secrets Workflow](../../ops/runbooks/1password-secrets-workflow.md) — Script quick reference
- [ADR-0022: Komodo-Managed NAS Stacks](/docs/adr/ADR-0022-truenas-komodo-stacks.md) — Architecture decision
- [Stacks Deployment Runbook](/ops/runbooks/stacks-deployment.md) — Operational workflows
- [NAS Stacks Overview](/docs/STACKS.md)
