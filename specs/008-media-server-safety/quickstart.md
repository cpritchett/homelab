# Quickstart: Critical Service Safety

## What this feature does

Prevents the deployment agent from restarting media servers (Plex, Jellyfin) when users are actively streaming. The agent checks for active sessions before any deploy that would affect these services.

## Implementation overview

This is a **governance + agent behavior** feature, not a traditional code feature. The deliverables are:

1. **`config/critical-services.yaml`** — Registry of critical services with session-check definitions
2. **`contracts/agents.md`** update — Adds critical service safety as an agent operating rule
3. **Komodo deploy skill** update — Adds pre-deploy session check logic to the deployment workflow
4. **Agent memory** update — Already done; reinforces the constraint across sessions
5. **1Password items** — API tokens for Plex and Jellyfin session queries

## How it works

```
Operator: "deploy application_media_core"
    │
Agent reads config/critical-services.yaml
    │
Agent finds: Plex and Jellyfin are critical in this stack
    │
Agent queries Plex and Jellyfin session APIs
    │
├── No active sessions → deploys normally
│
└── Active sessions found →
    Agent: "2 active streams on Plex (user1: Movie, user2: TV Show).
           Deploy will restart Plex. Proceed anyway?"
    │
    ├── Operator: "yes" → deploys with override logged
    └── Operator: "no"  → deploy aborted
```

## Files to create/modify

| File | Action | Purpose |
| ---- | ------ | ------- |
| `config/critical-services.yaml` | Create | Critical service registry |
| `contracts/agents.md` | Modify | Add critical service safety rule |
| Komodo deploy skill | Modify | Add session-check before deploy |
| 1Password: `plex` item | Create | `X_PLEX_TOKEN` for session API |
| 1Password: `jellyfin` item | Create | `API_KEY` for session API |

## Verification

1. Start playing something on Plex or Jellyfin
2. Ask the agent to deploy `application_media_core`
3. Verify the agent blocks the deploy and reports the active stream
4. Confirm the override, verify deploy proceeds
5. With no streams, verify deploy proceeds without prompting
