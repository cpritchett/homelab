---
description: "Deploy, redeploy, update, or manage homelab infrastructure via Komodo km CLI. Use whenever changes need to reach the homelab — deploying stacks, pushing config changes, adding or removing services, updating images, modifying compose files, changing secrets, or mutating any part of the running infrastructure. Also use when troubleshooting deployment failures or service health."
---

# Komodo Deploy Skill

You are deploying or managing stacks in the homelab via the Komodo `km` CLI.
Follow the governance rules, workflow, and troubleshooting steps below exactly.

---

## 1. Governance Rules (HARD STOPS)

| Tier | How to identify | Deploy method | Notes |
|------|----------------|--------------|-------|
| **Infrastructure (bootstrap)** | caddy, op-connect, komodo — NOT in `resources.toml` | `docker stack deploy` via SSH | Bootstrap only — these run before Komodo exists |
| **Platform** | `platform_*` stacks in `resources.toml` | **`km` ONLY** | Violating this = ADR-0022 governance breach |
| **Application** | `application_*` stacks in `resources.toml` | **`km` ONLY** | Same rule as platform tier |
| **Infrastructure (managed)** | `infrastructure_*` stacks in `resources.toml` | **`km` ONLY** | Komodo manages these even though they're infra |
| **Compose (non-Swarm)** | Stacks with `server` field (not `swarm`) in `resources.toml` | **`km` ONLY** | Compose mode, still managed by Komodo |

**NEVER use `docker stack deploy` or `docker compose up` for platform or application tier stacks.**
**NEVER fall back to SSH + docker commands when `km` fails — troubleshoot `km` first.**

---

## 2. km CLI Reference

**Binary:** `/Users/cpritchett/bin/km`
**Profile flag:** `--profile barbary` (ALWAYS required)
**Auto-confirm:** `-y` (skip confirmation prompts)

### Key commands

```sh
# Deploy a single stack
/Users/cpritchett/bin/km --profile barbary execute -y deploy-stack <STACK_NAME>

# Pull latest repo (do this before deploy if you just pushed)
/Users/cpritchett/bin/km --profile barbary execute -y pull-repo homelab-repo

# Sync resources.toml changes
/Users/cpritchett/bin/km --profile barbary execute -y run-sync homelab-resources

# List all stacks and their status
/Users/cpritchett/bin/km --profile barbary list stacks

# List stacks matching a pattern
/Users/cpritchett/bin/km --profile barbary list stacks -n "<pattern>"

# Batch deploy stacks matching a pattern
/Users/cpritchett/bin/km --profile barbary execute -y batch-deploy-stack "<pattern>"
```

### Command aliases
- `deploy-stack` = `stack` = `st`

---

## 3. Standard Deployment Workflow

Follow these steps in order:

1. **Commit and push** changes to `main`
2. **Pull repo** on the server:
   ```sh
   /Users/cpritchett/bin/km --profile barbary execute -y pull-repo homelab-repo
   ```
3. **Sync resources** (if `komodo/resources.toml` changed):
   ```sh
   /Users/cpritchett/bin/km --profile barbary execute -y run-sync homelab-resources
   ```
4. **Deploy the stack**:
   ```sh
   /Users/cpritchett/bin/km --profile barbary execute -y deploy-stack <STACK_NAME>
   ```
5. **Verify**:
   ```sh
   /Users/cpritchett/bin/km --profile barbary list stacks
   ```

If deploying multiple stacks, respect dependency order (section 4).

---

## 4. Stack Names and Dependencies (DYNAMIC)

**Do not rely on a hardcoded list.** Always read the current stacks and dependencies
from the source of truth before acting:

```
Read komodo/resources.toml
```

Parse every `[[stack]]` entry to build your working knowledge:

- **Stack name:** `name` field
- **Deploy mode:** `swarm = "homelab-swarm"` → Swarm stack; `server = "barbary-periphery"` → Compose stack
- **Tier:** Infer from the name prefix:
  - `platform_*` → Platform tier → **km only**
  - `application_*` → Application tier → **km only**
  - `infrastructure_*` → Infrastructure tier (Komodo-managed) → **km only**
  - No prefix (e.g., `dnsmasq-proxypxe`, `smartctl-exporter`) → check `server` vs `swarm` field → **km only**
  - Infrastructure bootstrap stacks (caddy, op-connect, komodo) are NOT in resources.toml — they use `docker stack deploy` via SSH
- **Dependencies:** `after = [...]` field — deploy these stacks FIRST
- **Pre-deploy script:** `pre_deploy.command` field
- **Config files:** `config_files` entries — changes trigger restart
- **Ignored services:** `ignore_services` — excluded from health checks (init jobs, cron jobs)

### Dependency resolution

When deploying multiple stacks, build a dependency graph from `after` fields:
1. Stacks with no `after` field can deploy in any order (or in parallel with `batch-deploy-stack`)
2. Stacks with `after` must wait for those dependencies to complete first
3. If deploying everything, topologically sort by `after` relationships

---

## 5. Troubleshooting Escalation Ladder

Work through these IN ORDER. Do not skip to SSH.

### Level 1: "EXECUTION FAILED" instantly (< 1 second)
**Cause:** Lock contention — another deploy is holding the stack lock.
**Fix:** Wait 30 seconds and retry. If persistent, check for stuck updates:
```sh
# Query stuck updates via km
/Users/cpritchett/bin/km --profile barbary list updates
```
If an update is stuck `InProgress`, restart `komodo_core` to clear in-memory locks (requires SSH — this is an acceptable SSH use).

### Level 2: Deploy fails — repo content stale
**Cause:** Forgot to pull after push.
**Fix:**
```sh
/Users/cpritchett/bin/km --profile barbary execute -y pull-repo homelab-repo
# Then retry deploy
```

### Level 3: Pre-deploy script failed
**Cause:** Missing directory, wrong ownership, missing 1Password secret.
**Fix:** Read the error output carefully. The validate scripts use `ensure_dir_with_ownership()` — fix the underlying issue (create dir, fix perms, create 1Password item), then retry.

### Level 4: Periphery websocket deadlock
**Symptom:** "Receiver is already locked" in logs, deploys hang indefinitely.
**Fix (SSH required — acceptable):**
```sh
ssh truenas_admin@barbary "sudo docker service update --force komodo_periphery && sudo docker service update --force komodo_core"
```

### Level 5: SSH fallback (LAST RESORT)
**Only when:** `km` binary is broken, Komodo API is completely down, or Periphery is unreachable.
**Requirements before using SSH:**
1. Document WHY `km` cannot work
2. Use `docker stack deploy` with the exact same compose file Komodo would use
3. After the emergency, verify `km` works again and redeploy via `km`

---

## 6. resources.toml Quick Reference

Key fields in `[[stack]]` entries:

| Field | Purpose |
|-------|---------|
| `swarm = "homelab-swarm"` | Deploy as Swarm stack (via `docker stack deploy` under the hood) |
| `server = "barbary-periphery"` | Deploy as Compose stack (via `docker compose up -d`) |
| `linked_repo = "homelab-repo"` | Which repo contains the compose file |
| `run_directory` | Path within repo to the compose file directory |
| `file_paths` | Explicit compose file(s) if not `docker-compose.yaml` |
| `ignore_services` | Services excluded from health checks (init jobs, cron jobs) |
| `after` | Stack dependencies — Komodo enforces ordering |
| `auto_pull` | Komodo auto-pulls images before deploy |
| `config_files` | Files that trigger restart on change |
| `pre_deploy.path` + `pre_deploy.command` | Validation script run before deploy |

---

## 7. What NOT To Do

| Prohibition | Why |
|------------|-----|
| `ssh ... docker stack deploy` for platform/app stacks | Bypasses Komodo tracking, pre-deploy validation, dependency ordering |
| `docker service update --force` on app services | Use `km deploy-stack` instead — force-update is only for Komodo's own services |
| Editing compose files on the server directly | Server pulls from git — local edits get overwritten on next deploy |
| Skipping `pull-repo` after `git push` | Server repo will be stale; deploy ships old config |
| Using `docker compose up` on the server | Swarm stacks must use `docker stack deploy` (which `km` does internally) |
| Retrying a failed deploy 5+ times without investigating | Read the error. Fix the root cause. |

---

## Usage

When the user asks to deploy, redeploy, or manage a stack:

1. **Read `komodo/resources.toml`** to get current stack names, tiers, and dependencies
2. Identify the target stack and confirm its tier — if infrastructure bootstrap, SSH is OK; otherwise `km` only
3. If changes were just committed, follow the full workflow (section 3)
4. If only redeploying existing config, skip to step 4 of the workflow
5. If errors occur, follow the escalation ladder (section 5) in order
6. Always verify with `km list stacks` after deploy
