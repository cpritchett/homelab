# Implementation Plan: Critical Service Production Safety

**Branch**: `008-media-server-safety` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-media-server-safety/spec.md`

## Summary

Add a production safety constraint that prevents the deployment agent from restarting critical services (Plex, Jellyfin) when active streaming sessions exist. Implemented as a critical service registry (YAML config), agent operating rule (contracts/agents.md), and pre-deploy session check in the Komodo deploy skill.

## Technical Context

**Language/Version**: POSIX shell for scripts, YAML for configuration, Markdown for agent instructions
**Primary Dependencies**: Plex API, Jellyfin API, 1Password Connect (API tokens), SSH/curl
**Storage**: `config/critical-services.yaml` (version-controlled YAML)
**Testing**: Manual verification — simulate streams, attempt deploys, verify blocking behavior
**Target Platform**: Claude Code agent behavior + homelab infrastructure
**Project Type**: Governance/agent behavior (no application code)
**Performance Goals**: Session check completes in <5 seconds per service
**Constraints**: Must work from operator's Mac via Caddy proxy URLs; must degrade safely (unreachable = assume active)
**Scale/Scope**: 2 critical services initially (Plex, Jellyfin); extensible to any service with a session API

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
| --------- | ------ | ----- |
| I. Management is Sacred | PASS | No management network changes |
| II. DNS Encodes Intent | PASS | No DNS changes |
| III. External Access is Identity-Gated | PASS | Uses existing Caddy proxy routes; no new WAN exposure |
| IV. Routing Does Not Imply Permission | PASS | API tokens required for session checks |
| V. Prefer Structural Safety Over Convention | **ALIGNS** | This feature implements Principle V — making unsafe actions (restart during stream) structurally hard rather than relying on "we'll be careful" |

**Agent Rules compliance**:
- Agents MAY propose changes as PR-ready patches ✓
- No violations of contracts/invariants ✓
- No boundary collapse ✓

**Post-design re-check**: PASS — No changes to gate assessment. The design uses existing Caddy routes and 1Password patterns. The critical service registry is a new config file under version control, consistent with the repo structure rules.

## Project Structure

### Documentation (this feature)

```text
specs/008-media-server-safety/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: API research, storage decisions
├── data-model.md        # Phase 1: Critical service registry schema
├── quickstart.md        # Phase 1: Implementation overview
├── contracts/
│   └── session-check-api.md  # Phase 1: Plex/Jellyfin API contracts
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
config/
└── critical-services.yaml    # NEW — Critical service registry

contracts/
└── agents.md                 # MODIFY — Add critical service safety rule

# Agent skill (project settings, not in repo tree):
# komodo-deploy skill — MODIFY — Add pre-deploy session check
```

**Structure Decision**: No new `src/` or `tests/` directories needed. This is a governance feature implemented through configuration files and agent instruction updates.

## Complexity Tracking

No constitution violations to justify.
