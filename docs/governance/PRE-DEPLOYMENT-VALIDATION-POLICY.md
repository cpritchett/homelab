# Pre-Deployment Validation Script Policy

## When Validation Scripts Are Required

Pre-deployment validation scripts are **REQUIRED** if a stack meets ANY of these criteria:

### 1. Persistent State
Stack uses host-mounted volumes for persistent data:
- ✅ **Required**: PostgreSQL, MongoDB, Redis (databases with data directories)
- ✅ **Required**: Authentik, Grafana (applications with config/data directories)
- ❌ **Not Required**: Stateless apps (no persistent volumes)

### 2. Specific UID/GID Requirements
Stack containers run as non-root users with specific UID/GID:
- ✅ **Required**: Services requiring specific ownership (PostgreSQL as 999:999)
- ❌ **Not Required**: Services running as root or dynamic UIDs

### 3. External Service Dependencies
Stack requires other services to be running:
- ✅ **Required**: Services depending on 1Password Connect, specific networks, etc.
- ✅ **Required**: Services requiring Docker secrets to exist
- ❌ **Not Required**: Self-contained stacks with no external dependencies

### 4. Complex Initialization
Stack has multi-step initialization or ordering requirements:
- ✅ **Required**: Init containers that need specific setup
- ✅ **Required**: Services with database migrations or schema setup
- ❌ **Not Required**: Simple single-container services

### 5. Infrastructure Tier
All infrastructure tier stacks (`stacks/infrastructure/`):
- ✅ **Required**: Infrastructure is foundational, must validate thoroughly

## When Validation Scripts Are Optional

Validation scripts are **OPTIONAL** for:
- Stateless services (no persistent volumes)
- Services with no specific UID/GID requirements
- Self-contained stacks with no external dependencies
- Simple single-container applications
- Read-only services

**Examples:**
- ❌ Simple web dashboard (no state, no dependencies)
- ❌ Read-only monitoring exporter
- ❌ Stateless API proxy

## Validation Script Requirements

When a validation script is required, it MUST:

### 1. Be Idempotent
```bash
# ✅ Good - Check before acting
if [ ! -d "$DIR" ]; then
    mkdir -p "$DIR"
    log "Created: $DIR"
fi

# ❌ Bad - Always acts
mkdir -p "$DIR"
```

### 2. Not Perform Git Operations
```bash
# ❌ Prohibited - Komodo handles git
git pull origin main

# ✅ Correct - Assume Komodo synced
# No git commands at all
```

### 3. Not Deploy Stacks
```bash
# ❌ Prohibited - Komodo handles deployment
docker stack deploy -c compose.yaml mystack

# ✅ Correct - Only validate
# No deployment commands
```

### 4. Fail Fast on Missing Prerequisites
```bash
# ✅ Good - Exit immediately if prerequisite missing
if ! docker network inspect proxy_network >/dev/null 2>&1; then
    log_error "proxy_network not found. Deploy infrastructure tier first."
    exit 1
fi
```

### 5. Be Fast (< 10 seconds)
- Scripts run before every deployment
- Should complete quickly
- Only do necessary validation
- Avoid expensive operations

### 6. Follow Naming Convention
- Location: `scripts/validate-<stack>-setup.sh`
- Example: `scripts/validate-authentik-setup.sh`
- Example: `scripts/validate-grafana-setup.sh`

### 7. One-Shot Secret Hydration Pattern
- If a stack uses `op inject`/template hydration, model that service as a one-shot Swarm job:
  - `deploy.mode: replicated-job`
  - `deploy.restart_policy.condition: none`
- Do NOT run secret hydration as an always-on replica just to appear `1/1`.
- Expected successful state for job services is `0/1 (1/1 completed)`.
- If a stack supports existing secret files as fallback, the job may exit `0` when fallback is valid; otherwise it MUST fail fast.

## Script Template

```bash
#!/bin/sh
###############################################################################
# <Stack Name> - Pre-Deployment Validation & Setup
#
# Purpose: Validate prerequisites and prepare environment for <Stack>
# Tier: <Infrastructure|Platform|Application>
#
# Per ADR-0022: This script is run by Komodo as a pre-deployment hook.
# It is IDEMPOTENT and safe to run before every deployment.
#
# This script:
#   1. Validates prerequisites (dependencies, secrets, networks)
#   2. Creates required directories with correct permissions (if not exists)
#   3. Tests connectivity to required services
#   4. Does NOT pull from git (Komodo handles git sync)
#   5. Does NOT deploy the stack (Komodo handles deployment)
#
# POSIX-compatible: Works with sh, bash, dash, etc.
###############################################################################

set -eu

# Configuration
APPDATA_PATH="${APPDATA_PATH:-/mnt/apps01/appdata}"

# Logging
log() { echo "[<stack>-validation] $*"; }
log_error() { echo "[<stack>-validation] ERROR: $*" >&2; }

# Verify running as root (if needed) - POSIX-compatible
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Validate Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running"
    exit 1
fi

# Validate prerequisites (networks, secrets, services)
if ! docker network inspect proxy_network >/dev/null 2>&1; then
    log_error "proxy_network not found"
    exit 1
fi

# Helper: Create directory with ownership if needed
ensure_dir_with_ownership() {
    local dir="$1" owner="$2" perms="$3"

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chown "$owner" "$dir"
        chmod "$perms" "$dir"
        log "Created: $dir (${owner}, ${perms})"
    else
        # Check and fix ownership/permissions if needed
        local current_owner=$(stat -c '%u:%g' "$dir" 2>/dev/null || stat -f '%u:%g' "$dir")
        if [ "$current_owner" != "$owner" ]; then
            chown "$owner" "$dir"
            log "Fixed ownership: $dir → $owner"
        fi
    fi
}

# Create required directories
ensure_dir_with_ownership "${DATA_PATH}/<stack>" "1000:1000" "755"

# Test connectivity to dependencies (if any)
# Example: Test 1Password Connect
# if ! docker run --rm --network op-connect_op-connect \
#     curlimages/curl:latest curl -sf -m 5 http://op-connect-api:8080/health >/dev/null 2>&1; then
#     log_error "Cannot reach 1Password Connect API"
#     exit 1
# fi

log "✅ Pre-deployment validation complete"
exit 0
```

## Komodo Configuration

For stacks with validation scripts:

1. Navigate to Stack → Configure in Komodo UI
2. Set **Pre-Deploy Hook**: `scripts/validate-<stack>-setup.sh`
3. Komodo runs this automatically before every deployment

## Exemptions

**Infrastructure Bootstrap:**
- `scripts/truenas-init-bootstrap.sh` is exempt (handles deployment)
- Infrastructure tier bootstraps before Komodo exists
- This is the only deployment script allowed

## Decision Matrix

Use this table to determine if your stack needs a validation script:

| Stack Characteristics | Validation Required? | Example |
|----------------------|---------------------|---------|
| Has persistent volumes | ✅ Yes | PostgreSQL, Authentik |
| Specific UID/GID | ✅ Yes | Most databases |
| External dependencies | ✅ Yes | Services using 1Password Connect |
| Complex init | ✅ Yes | Multi-stage initialization |
| Infrastructure tier | ✅ Yes | All infrastructure stacks |
| Stateless, no deps | ❌ No | Simple web dashboard |
| Single container, root user | ❌ No | Basic monitoring exporter |

## Examples

### Required Validation Scripts
- ✅ `validate-authentik-setup.sh` - Has volumes, specific UIDs, 1Password dependency
- ✅ `validate-grafana-setup.sh` - Has persistent data, config directories
- ✅ `validate-postgres-setup.sh` - Database with strict UID requirements
- ✅ All infrastructure stacks - Foundational services

### Required Secret-Hydration Service Pattern
- ✅ `secrets-init` / `op-secrets` services use Swarm job mode (`replicated-job`)
- ✅ Success is represented by completion (`0/1 (1/1 completed)`)
- ❌ Long-running "init" sidecars used only for UI green status

### Optional (Can Skip)
- ❌ Simple Homepage dashboard clone with no state
- ❌ Read-only Prometheus exporter
- ❌ Stateless Cloudflare Tunnel connector

## Enforcement

During code review, check:
- [ ] Stack has persistent volumes → validation script required
- [ ] Stack has specific UID/GID → validation script required
- [ ] Stack has external dependencies → validation script required
- [ ] Infrastructure tier → validation script required
- [ ] Validation script is idempotent
- [ ] Validation script has no git operations
- [ ] Validation script has no deployment operations
- [ ] Script completes in < 10 seconds

## References

- [ADR-0022: Komodo-Managed NAS Stacks](../adr/ADR-0022-truenas-komodo-stacks.md)
- [Service Deployment Checklist](./SERVICE_DEPLOYMENT_CHECKLIST.md)
- Template: `scripts/validate-authentik-setup.sh` (reference implementation)
