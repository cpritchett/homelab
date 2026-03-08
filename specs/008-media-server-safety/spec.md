# Feature Specification: Critical Service Production Safety Constraint

**Feature Branch**: `008-media-server-safety`
**Created**: 2026-03-08
**Status**: Draft
**Input**: User description: "Add production safety constraint for critical services (Plex, Jellyfin). Never restart critical services or their dependencies when active sessions exist. Support annotating services as critical vs non-critical."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Prevent Disruption of Critical Services During Deploy (Priority: P1)

As a homelab operator, I want the deployment agent to refuse to restart any service annotated as "critical" — or any service that a critical service depends on — when that critical service has active sessions, so that end users are never interrupted.

**Why this priority**: Critical services (e.g., Plex, Jellyfin) serve real users in real time. Interrupting an active stream or killing a dependency mid-session causes immediate, visible disruption.

**Independent Test**: Annotate Plex as critical. Simulate an active Plex stream, then attempt a deploy that would restart Plex or a service Plex depends on. Verify the agent blocks the deploy.

**Acceptance Scenarios**:

1. **Given** a critical service (Plex) has active sessions, **When** the agent attempts to deploy the stack containing that service, **Then** the deploy is blocked and the operator is informed of the active session count.
2. **Given** a critical service (Jellyfin) has active sessions, **When** the agent attempts to restart a dependency of that service (e.g., a shared database or network), **Then** the deploy is blocked.
3. **Given** no critical services have active sessions, **When** the agent deploys, **Then** the deploy proceeds normally.
4. **Given** a non-critical service in the same stack has no active sessions but a critical service does, **When** a full stack redeploy is requested, **Then** the deploy is blocked because the critical service would be affected.

---

### User Story 2 - Annotate Services as Critical (Priority: P1)

As a homelab operator, I want to annotate specific services as "critical" with a defined method for checking active sessions, so that the safety constraint knows which services to protect and how to check their status.

**Why this priority**: The constraint is only useful if the agent knows which services are critical and how to determine if they have active sessions. This is foundational.

**Independent Test**: Add a critical service annotation for Plex. Verify the agent recognizes Plex as critical and knows how to check for active sessions.

**Acceptance Scenarios**:

1. **Given** a service is annotated as critical with a session-check method, **When** the agent reads the annotation, **Then** the agent can determine whether that service has active sessions.
2. **Given** a service is NOT annotated as critical, **When** the agent deploys the stack, **Then** no session check is performed for that service.
3. **Given** a new service needs to be marked critical, **When** the operator adds the annotation, **Then** the agent enforces the constraint on the next deploy without code changes.

---

### User Story 3 - Operator Override for Urgent Deploys (Priority: P2)

As a homelab operator, I want the ability to override the safety check and force a deploy even when critical services have active sessions, so that I can handle emergencies (security patches, critical bugs) without waiting for all sessions to end.

**Why this priority**: Safety checks must not create an unbreakable lock. The operator is the final authority and needs an escape hatch.

**Independent Test**: With an active stream on a critical service, instruct the agent to deploy with explicit confirmation. Verify the agent proceeds after acknowledgement.

**Acceptance Scenarios**:

1. **Given** a critical service has active sessions and the operator explicitly confirms they want to proceed, **When** the agent deploys, **Then** the deploy executes and the override is logged.
2. **Given** a critical service has active sessions and the operator does not confirm, **When** the agent is asked to deploy, **Then** the deploy remains blocked.

---

### User Story 4 - Non-Critical Service Deploys Pass Through (Priority: P3)

As a homelab operator, I want deploys that only affect non-critical services to proceed without session checks, so that routine maintenance is not unnecessarily blocked.

**Why this priority**: The safety constraint should be targeted. Blocking all operations when only specific services are sensitive would slow down routine work.

**Independent Test**: Deploy a stack that contains no critical services. Verify no session check is triggered.

**Acceptance Scenarios**:

1. **Given** the operator deploys a stack with no critical services, **When** the deploy is initiated, **Then** no session check is performed.
2. **Given** a stack contains both critical and non-critical services, **When** a full stack redeploy is requested and a critical service has active sessions, **Then** the deploy is blocked for the entire stack.

---

### Edge Cases

- What happens when the session-check mechanism for a critical service is unreachable? The agent MUST treat unreachable as "sessions may be active" and ask the operator before proceeding.
- What happens when a session starts between the check and the actual deploy? This is an accepted race condition; the check is best-effort, not transactional.
- What happens when one critical service in a stack has sessions but another does not? Any critical service with active sessions blocks the deploy for the entire stack.
- What happens when a dependency is shared across multiple stacks (e.g., a database used by both a critical and non-critical stack)? The constraint applies to the critical service's own stack plus any cross-stack dependencies explicitly listed in the critical service annotation. Unlisted stacks are not blocked.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST support annotating individual services as "critical" with a defined method for checking active sessions (e.g., an API endpoint that returns session count).
- **FR-002**: The deployment agent MUST check for active sessions on all critical services before deploying any stack that contains a critical service or a dependency of a critical service.
- **FR-003**: The agent MUST block the deploy and inform the operator when one or more critical services have active sessions, including the count, which services are affected, and which users/sessions are active (if available).
- **FR-004**: The agent MUST allow the operator to explicitly override the safety check and proceed with the deploy after acknowledging the impact.
- **FR-005**: The agent MUST treat an unreachable session-check endpoint as "potentially active sessions" and ask the operator before proceeding.
- **FR-006**: The agent MUST NOT apply session checks to deploys that do not affect any critical service or its dependencies.
- **FR-007**: The constraint MUST be documented in the project constitution, agent memory, and deployment skill so that all agent sessions enforce it automatically.

### Key Entities

- **Critical Service**: A service annotated as requiring active-session protection before restart. Defined by: service name, stack membership, session-check method (API endpoint + response parsing), and optionally a list of cross-stack dependencies whose restart should also be blocked when sessions are active.
- **Active Session**: A user session on a critical service in "playing" or "paused" state. Idle or merely connected sessions do not count. A paused session is treated as active because the user likely intends to resume shortly.
- **Session Check**: A query to a critical service's API to determine whether active sessions exist. Returns session count and optionally user/session details.
- **Deploy Target**: A Komodo-managed stack that may contain critical services. A deploy of the stack restarts all services within it.

### Initial Critical Services

The following services are critical at launch:

| Service   | Stack                    | Session Check                        | Dependency Impact                                   |
| --------- | ------------------------ | ------------------------------------ | --------------------------------------------------- |
| Plex      | application_media_core   | Plex API: active session count       | Same-stack; no cross-stack deps initially            |
| Jellyfin  | application_media_core   | Jellyfin API: active session count   | Same-stack; no cross-stack deps initially            |

Additional services can be annotated as critical in the future by adding entries to the annotation mechanism.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero unintended session interruptions caused by agent-initiated deploys after this constraint is in place.
- **SC-002**: 100% of deploys affecting critical services are preceded by a session check (or an explicit operator override).
- **SC-003**: Operator can override and force-deploy within 10 seconds of being informed of active sessions.
- **SC-004**: Non-critical service updates are not delayed by unnecessary session checks.
- **SC-005**: Adding a new critical service requires only a configuration change (annotation), not code or agent instruction changes.

## Clarifications

### Session 2026-03-08

- Q: What session states count as "active" for the safety check? → A: "Playing" and "paused" sessions count as active; idle or merely connected sessions are ignored.
- Q: What is the dependency scope for blocking deploys? → A: Same-stack plus explicitly listed cross-stack dependencies (configurable per critical service). Unlisted stacks are not blocked.

## Assumptions

- Plex exposes session info via its API (`/status/sessions`). Jellyfin exposes session info via its API (`/Sessions`).
- The deployment agent has network access to query these APIs from the operator's machine via the Caddy reverse proxy URLs (e.g., `plex.in.hypyr.space`, `jellyfin.in.hypyr.space`).
- The constraint is enforced at the agent behavior level (agent instructions, memory, constitution, deployment skill) rather than as a technical gate in CI/CD.
- A full stack redeploy via `km deploy-stack` restarts all services in the stack; Komodo does not support selectively updating individual Swarm services without redeploying the entire stack.
- The critical service annotation is stored in a project file (e.g., a YAML/TOML config) that the agent reads before each deploy, making it easy to add/remove critical services.
