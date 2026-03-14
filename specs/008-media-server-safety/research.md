# Research: Critical Service Production Safety

## Decision 1: Where to store critical service annotations

**Decision**: A dedicated YAML file at `config/critical-services.yaml` in the repo root.

**Rationale**: The agent reads this file before each deploy. YAML is human-readable, version-controlled, and easily extensible. Keeping it separate from `resources.toml` (Komodo config) and `CLAUDE.md` (agent instructions) maintains separation of concerns. The agent instructions reference this file by path.

**Alternatives considered**:
- `resources.toml` metadata — Komodo doesn't support custom metadata fields in stack definitions
- `CLAUDE.md` inline — mixes operational config with agent behavior instructions; harder to parse programmatically
- Agent memory (`MEMORY.md`) — not version-controlled in the main repo, not visible in PRs

## Decision 2: How the agent checks active sessions

**Decision**: The agent SSHes to barbary and runs `curl` via `docker exec` into a container on the media overlay network, querying each critical service's API. Alternatively, query via the Caddy reverse proxy URLs (`plex.in.hypyr.space`, `jellyfin.in.hypyr.space`) which are accessible from the operator's machine.

**Rationale**: The Caddy proxy route is simpler (no SSH/docker exec), and both Plex and Jellyfin are already exposed via Caddy without forward auth (they handle their own auth). The agent needs API tokens stored in 1Password.

**Alternatives considered**:
- Direct overlay network access — not possible from operator's Mac
- SSH + docker exec — works but more complex; Caddy route is equivalent and simpler
- Komodo API — Komodo doesn't expose container-level API proxying

## Decision 3: Session API details

### Plex
- **Endpoint**: `GET /status/sessions` on port 32400
- **Auth**: `X-Plex-Token` query parameter (stored in 1Password)
- **Response**: JSON (with `Accept: application/json` header). `MediaContainer.size` = session count. Each session has `Player.state` (`"playing"` or `"paused"`).
- **Active = playing or paused**. Idle users have no session entry (endpoint only returns active media sessions).

### Jellyfin
- **Endpoint**: `GET /Sessions` on port 8096
- **Auth**: `ApiKey` query parameter or `Authorization: MediaBrowser Token="..."` header (stored in 1Password)
- **Response**: JSON array of ALL sessions (including idle). Filter by: `NowPlayingItem` present = media loaded; `PlayState.IsPaused` = true/false.
- **Active = `NowPlayingItem` present** (covers both playing and paused). Idle sessions have no `NowPlayingItem`.

### Access method
- **Primary**: Via Caddy proxy URLs (`https://plex.in.hypyr.space`, `https://jellyfin.in.hypyr.space`)
- **Fallback**: SSH + docker exec if Caddy is down

## Decision 4: Where to codify the constraint

The constraint must be recorded in three places:

1. **`contracts/agents.md`** — Add a "Critical service safety" section under Prohibited Actions or as a new Required Workflow. This is the authoritative governance source.
2. **Komodo deploy skill** (`.claude/projects/.../komodo-deploy` or equivalent skill file) — Add pre-deploy session check logic to the deployment workflow.
3. **Agent memory** (`MEMORY.md`) — Already done. Ensures cross-session persistence.

## Decision 5: API token storage

- **Plex token**: Create 1Password item `plex` with field `X_PLEX_TOKEN` in homelab vault (or add to existing item if one exists)
- **Jellyfin API key**: Create 1Password item `jellyfin` with field `API_KEY` in homelab vault (or add to existing item)

The agent retrieves these via 1Password Connect API or asks the operator for the values when needed.
