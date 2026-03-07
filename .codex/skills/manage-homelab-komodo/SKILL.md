---
name: manage-homelab-komodo
description: Manage, deploy, redeploy, diagnose, and troubleshoot this homelab's Docker Swarm and compose-mode stacks through the Komodo `km` CLI. Use when checking homelab health, investigating stack states, explaining unhealthy or down services, resolving Komodo deploy failures, pulling or syncing `komodo/resources.toml` changes, or deploying stack changes that should reach the live environment.
---

# Manage Homelab Komodo

Operate this homelab through Komodo first. Read repo state and Komodo state before proposing fixes, and treat `komodo/resources.toml` plus the relevant compose files as the source of truth for stack behavior.

## Governance

Read the repo authority chain before acting:

1. `constitution/constitution.md`
2. `contracts/hard-stops.md`
3. `contracts/invariants.md`
4. `contracts/agents.md`
5. `docs/governance/agent-contract.md`

Follow these rules strictly:

- Use `km` for all Komodo-managed stacks.
- Do not use `docker stack deploy` or `docker compose up` for stacks defined in `komodo/resources.toml`.
- Treat bootstrap infra separately: `caddy`, `op-connect`, and `komodo` are not Komodo-managed.
- Do not SSH or run direct docker commands unless Komodo cannot perform the task or the escalation ladder explicitly requires it.
- Pause for explicit user approval before SSH, direct docker operations, force-restarting Komodo services, or destructive actions.

## Core Commands

Use the repo's established Komodo CLI form:

```sh
/Users/cpritchett/bin/km --profile barbary execute -y deploy-stack <STACK_NAME>
/Users/cpritchett/bin/km --profile barbary execute -y pull-repo homelab-repo
/Users/cpritchett/bin/km --profile barbary execute -y run-sync homelab-resources
/Users/cpritchett/bin/km --profile barbary execute -y batch-deploy-stack "<PATTERN>"
/Users/cpritchett/bin/km --profile barbary list stacks --all
/Users/cpritchett/bin/km --profile barbary list stacks --in-progress
/Users/cpritchett/bin/km --profile barbary list servers --all
```

## Workflow

### 1. Build current stack knowledge

Never rely on a hardcoded stack list. Read `komodo/resources.toml` and extract:

- `[[stack]].name`
- `swarm` vs `server`
- `after`
- `run_directory`
- `file_paths`
- `ignore_services`
- `pre_deploy.command`
- `config_files`

Infer tier from the stack name and config:

- `platform_*`, `application_*`, and `infrastructure_*` in `resources.toml` are Komodo-managed.
- Stacks with `server = ...` are compose-mode but still Komodo-managed.
- Bootstrap infra stacks are outside `resources.toml`.

### 2. Investigate before concluding

When a stack is `unhealthy`, `down`, or stuck `deploying`:

1. Run `km list stacks --all`.
2. Read the stack entry in `komodo/resources.toml`.
3. Read the compose file from `run_directory` and `file_paths`.
4. Read any referenced validation script from `pre_deploy.command`.
5. Read nearby `.env.template` files if secrets or paths may be involved.

Use the code to explain status before escalating:

- `mode: replicated-job`, `restart_policy.condition: none`, or `replicas: 0` often make `down` expected.
- `ignore_services` often explains noisy `unhealthy` reports.
- `healthcheck` definitions explain what Komodo is actually waiting on.

### 3. Standard deploy path

Use this order when changes should reach the live homelab:

1. Confirm the relevant change exists in the repo.
2. Pull repo content on the server:
   ```sh
   /Users/cpritchett/bin/km --profile barbary execute -y pull-repo homelab-repo
   ```
3. If `komodo/resources.toml` changed, sync resources:
   ```sh
   /Users/cpritchett/bin/km --profile barbary execute -y run-sync homelab-resources
   ```
4. Deploy the target stack:
   ```sh
   /Users/cpritchett/bin/km --profile barbary execute -y deploy-stack <STACK_NAME>
   ```
5. Verify with:
   ```sh
   /Users/cpritchett/bin/km --profile barbary list stacks --all
   ```

When deploying multiple stacks, respect `after = [...]` dependencies from `komodo/resources.toml`.

## Troubleshooting Ladder

Work this ladder in order. Do not jump to SSH first.

### Level 1: Instant execution failure

Likely lock contention. Wait briefly, then retry. If still blocked, inspect:

```sh
/Users/cpritchett/bin/km --profile barbary list stacks --in-progress
```

### Level 2: Deploy uses stale repo content

Pull the linked repo, then retry:

```sh
/Users/cpritchett/bin/km --profile barbary execute -y pull-repo homelab-repo
```

### Level 3: Pre-deploy validation failure

Read the validation script output and fix the underlying issue in repo or environment. Common causes:

- missing directories
- wrong ownership
- missing 1Password items
- absent config files or bad paths

### Level 4: Periphery websocket deadlock

Symptoms include hanging deploys and `Receiver is already locked`. This requires SSH approval before running:

```sh
ssh truenas_admin@barbary "sudo docker service update --force komodo_periphery && sudo docker service update --force komodo_core"
```

### Level 5: SSH fallback

Use only when Komodo itself is broken or unreachable. Before using SSH:

1. Document why `km` cannot work.
2. Use the same compose path Komodo would have used.
3. Plan to return to Komodo-managed operation after the emergency.

## Operating Posture

Take initiative on read-only investigation:

- read repo files
- inspect `komodo/resources.toml`
- run `km list` commands
- correlate statuses with compose semantics
- produce a concrete remediation plan

For safe Komodo mutations, state the plan and execute unless the user objects:

- `pull-repo`
- `run-sync`
- `deploy-stack`
- `batch-deploy-stack`

Always stop for explicit approval before:

- any `ssh ...`
- direct docker commands
- force-updating Komodo services
- deleting stacks, services, or data

## Response Shape

When reporting health or a failure, give a single concise summary with:

1. what is healthy
2. what is expected-noisy or expected-down
3. what needs attention
4. the next command you will run or the approval you need
