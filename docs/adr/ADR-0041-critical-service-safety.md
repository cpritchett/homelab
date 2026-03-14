# ADR-0041: Critical Service Production Safety

**Status**: Accepted
**Date**: 2026-03-08
**Deciders**: cpritchett (repo owner)

---

## Context

Media servers (Plex, Jellyfin) in the homelab actively serve streaming users. Agent-initiated deploys of `application_media_core` restart all services in the stack, including these media servers. Restarting during an active stream causes immediate, visible disruption to end users.

Previously, the only safeguard was operator memory — "remember to check if anyone is streaming before deploying." This violates Constitution Principle V: "Prefer Structural Safety Over Convention."

---

## Decision

Add a mandatory pre-deploy session check for critical services:

1. A YAML registry at `config/critical-services.yaml` defines which services are critical and how to check for active sessions
2. The `contracts/agents.md` operating rule requires agents to check this registry before any deploy
3. The `komodo-deploy` skill implements the check: query each critical service's session API, block if active sessions (playing/paused) are detected, allow operator override
4. Constitution AMENDMENT-0004 formalizes this as an operating rule

---

## Rationale

1. **Structural over conventional**: The check is embedded in the deploy workflow, not reliant on operator memory
2. **Extensible**: New critical services are added by editing the YAML registry — no code changes needed
3. **Operator authority preserved**: Override is always available with explicit confirmation
4. **Safe degradation**: Unreachable APIs are treated as "potentially active" — the system errs on the side of caution

---

## Consequences

### Allowed

- Blocking deploys when active streaming sessions are detected
- Operator override with logged confirmation
- Adding new critical services via config file only

### Not allowed

- Silently restarting critical services during active sessions
- Bypassing the check without operator confirmation
- Removing the check without a superseding ADR

---

## Implementation

1. `config/critical-services.yaml` — Critical service registry
2. `contracts/agents.md` — "Required: Critical Service Safety" operating rule
3. `.claude/commands/komodo-deploy.md` — Pre-deploy session check (section 3a)
4. `constitution/amendments/AMENDMENT-0004-critical-service-safety.md` — Constitutional amendment

---

## Related

- [Constitution Principle V](../../constitution/constitution.md): Prefer Structural Safety Over Convention
- [AMENDMENT-0004](../../constitution/amendments/AMENDMENT-0004-critical-service-safety.md): Critical Service Safety
- [Spec 008](../../specs/008-media-server-safety/spec.md): Feature specification
