# Data Model: Critical Service Safety

## Entity: Critical Service Registration

Stored in `config/critical-services.yaml`.

```yaml
# config/critical-services.yaml
critical_services:
  - name: plex                          # Service name (matches compose service name)
    stack: application_media_core       # Komodo stack containing this service
    display_name: Plex                  # Human-readable name for operator messages
    session_check:
      url: "https://plex.in.hypyr.space/status/sessions"
      auth_param: "X-Plex-Token"         # Query parameter name appended to URL
      auth_secret: "op://homelab/plex/X_PLEX_TOKEN"  # 1Password reference
      method: plex                      # Parser type: plex | jellyfin
    cross_stack_deps: []                # Additional stacks blocked when sessions active

  - name: jellyfin
    stack: application_media_core
    display_name: Jellyfin
    session_check:
      url: "https://jellyfin.in.hypyr.space/Sessions"
      auth_param: "ApiKey"               # Query parameter name appended to URL
      auth_secret: "op://homelab/jellyfin/API_KEY"
      method: jellyfin
    cross_stack_deps: []
```

## Entity: Session Check Result

Returned by the agent's session-check logic (in-memory, not persisted).

| Field            | Type     | Description                                      |
| ---------------- | -------- | ------------------------------------------------ |
| service_name     | string   | Name of the critical service checked              |
| display_name     | string   | Human-readable name                               |
| reachable        | boolean  | Whether the API responded                         |
| active_sessions  | integer  | Count of playing + paused sessions                |
| sessions         | list     | Details: user, title, state (playing/paused)      |

## State Transitions

```
Deploy requested
    │
    ▼
Read config/critical-services.yaml
    │
    ▼
Stack contains critical services? ──No──► Proceed with deploy
    │
   Yes
    │
    ▼
For each critical service in stack:
  Query session API
    │
    ├─ Unreachable ──► Treat as "may be active"
    │
    ├─ 0 active sessions ──► Continue checking next service
    │
    └─ >0 active sessions ──► Block + inform operator
                                    │
                                    ▼
                              Operator confirms override?
                                    │
                              ├─ Yes ──► Proceed (log override)
                              └─ No  ──► Abort deploy
```

## Relationships

- A **Critical Service** belongs to exactly one **Stack** (its primary stack)
- A **Critical Service** may list zero or more **Cross-Stack Dependencies** (additional stacks blocked)
- A **Deploy Target** (stack) may contain zero or more **Critical Services**
- A **Session Check** produces one **Session Check Result** per critical service
