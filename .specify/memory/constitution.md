<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Reason: Added TLS/PKI invariants and hard-stop per ADR-0039
- Modified principles: None
- Added: TLS/PKI to invariant categories list, TLS verification to hard-stops list
- Templates requiring updates: None
- Follow-up TODOs: None
-->

# Homelab Infrastructure Constitution

**Domain:** hypyr.space
**Canonical Source:** `constitution/constitution.md`

This file is the speckit-readable representation of the project constitution.
For amendment procedures and full governance detail, see the canonical source.

## Core Principles

### I. Management is Sacred and Boring

The management network MUST remain isolated, predictable, and minimally
reachable. No overlay agents, no internet egress by default, no
non-console-initiated traffic into Management VLAN. Changes to management
network require explicit ADR with code-owner approval.

**Rationale:** Management infrastructure compromise cascades to every
other system. Boring means safe.

### II. DNS Encodes Intent

Names MUST describe trust boundaries. Public and internal services MUST
NOT share identical names. Internal zone (`in.hypyr.space`) MUST remain
internal-only. No additional internal suffixes (`.lan`, `.local`, `.home`
are prohibited). No split-horizon overrides.

**Rationale:** DNS naming is the first signal of what a service is and
where it belongs. Ambiguous names cause misconfiguration.

### III. External Access is Identity-Gated

External access MUST be mediated by Cloudflare Tunnel + Access, not WAN
exposure. No port forwards, no WAN-exposed listeners, no "temporary"
openings without documented exception.

**Rationale:** WAN exposure creates attack surface that scales with the
internet. Identity gating constrains access to authenticated principals.

### IV. Routing Does Not Imply Permission

Reachability MUST NOT grant authorization. Policy boundaries remain
authoritative. Just because a service can reach another does not mean it
is permitted to.

**Rationale:** Network adjacency is not an access control mechanism.

### V. Prefer Structural Safety Over Convention

Make unsafe actions hard. MUST NOT rely on memory, tribal knowledge, or
"we'll be careful." Invariants MUST be CI-enforced where checkable.
Secrets directories MUST be 750 or stricter. Pre-deploy validation
scripts MUST enforce correct ownership and permissions.

**Rationale:** Convention degrades under pressure; structure does not.

## Contracts & Constraints

Three types of operational contracts derive from these principles:

1. **Invariants** (`contracts/invariants.md`) — Conditions that MUST
   always be true. Categories: Network Identity, WAN, Storage, Hardware,
   Access, DNS, Repository Structure, Secrets Management, TLS/PKI, GitOps.

2. **Hard-Stops** (`contracts/hard-stops.md`) — Actions requiring human
   approval: exposing services to WAN, publishing internal zones
   publicly, allowing non-console Management access, installing overlay
   agents on Management devices, split-horizon to bypass Cloudflare
   Access, disabling TLS certificate verification.

3. **Agent Rules** (`contracts/agents.md`) — Agents MAY propose patches,
   add ADRs/docs/checklists. Agents MUST use PR/issue templates, fill
   all checklist items, provide CI evidence. Agents MUST NOT violate
   requirements/invariants, collapse boundaries, or assume network
   changes without ADR.

**Hierarchy:** Constitution > Contracts > Requirements.

## Development Workflow

- **Secrets:** 1Password is single source of truth. Docker Swarm stacks
  use `op inject` pattern via 1Password Connect. No plaintext secrets on
  disk (exception: op credentials file at 600 permissions).

- **Deployment:** Infrastructure tier via `docker stack deploy`.
  Platform/Application tiers via Komodo ResourceSync. Commit to main,
  Komodo auto-pulls.

- **Repository structure:** Root files exhaustively enumerated. Markdown
  on allowlist. Specs under `requirements/` or `specs/NNN-*/`. CI
  enforces all structural rules via `guardrails.yml`.

- **ADRs:** Required for changes to constitution, contracts, or
  requirements. Sequential numbering. Append-only (supersede, don't
  delete). Amendments use letter suffix (ADR-NNNN-amendment-A).

## Governance

This constitution is the highest authority in this repository. Any
change that conflicts with it is invalid unless the constitution is
amended first.

**Amendment process:**
1. Propose amendment file at `constitution/amendments/AMENDMENT-NNNN-topic.md`
2. Create supporting ADR at `docs/adr/ADR-NNNN-topic.md`
3. Update this constitution and downstream contracts/requirements
4. Code-owner approval required; all CI gates must pass
5. Amendments are append-only (reverse via new superseding amendment)

**Compliance:** All PRs and agent actions MUST verify compliance with
contracts and invariants. CI gates block violations automatically.

**Version**: 1.1.0 | **Effective**: 2025-12-14 | **Synced**: 2026-02-24
