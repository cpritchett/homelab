# AMENDMENT-0004: Critical Service Safety

**Status**: Accepted
**Date**: 2026-03-08
**Authority**: Constitution Principle V (Prefer Structural Safety Over Convention)
**ADR**: [ADR-0041](../../docs/adr/ADR-0041-critical-service-safety.md)
**Spec**: `specs/008-media-server-safety/spec.md`

---

## Amendment

Add the following agent operating rule to `contracts/agents.md` under Required Workflows:

> **Critical Service Safety**: Before deploying any Komodo-managed stack,
> agents MUST read `config/critical-services.yaml` and check for active
> sessions on any critical services in the target stack. If active sessions
> (playing or paused) are detected, the agent MUST block the deploy and
> inform the operator. The operator may explicitly override. If the session
> API is unreachable, the agent MUST treat it as "potentially active" and
> ask the operator before proceeding.

---

## Rationale

Principle V states: "Make unsafe actions hard. MUST NOT rely on memory,
tribal knowledge, or 'we'll be careful.'" Restarting media servers during
active streams causes immediate, visible disruption to end users. This
amendment makes the unsafe action (deploying during active streams)
structurally hard by requiring an explicit session check before any deploy
affecting critical services.

---

## Consequences

- `config/critical-services.yaml` becomes a version-controlled registry
  of services requiring session checks before restart
- The `komodo-deploy` agent skill enforces the check before `km deploy-stack`
- New critical services can be added by editing the YAML file (no code changes)
- Operators retain override authority via explicit confirmation

---

## Files Modified

1. `contracts/agents.md` — Added "Required: Critical Service Safety" section
2. `config/critical-services.yaml` — Created critical service registry
3. Komodo deploy skill (Claude Code project setting) — Added pre-deploy session check
