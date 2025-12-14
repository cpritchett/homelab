# Agent Operating Rules (Router)

This file is a **non-authoritative entrypoint** for humans and LLM agents.

## Canonical authority (read in this order)
1. `constitution/constitution.md` — immutable principles
2. `contracts/hard-stops.md` — actions requiring human approval
3. `contracts/invariants.md` — must always be true
4. `contracts/agents.md` — what agents may/must not do
5. `requirements/**/spec.md` — domain requirements (DNS/ingress/management/overlay)
6. `requirements/**/checks.md` — validation criteria
7. `docs/adr/*` — historical rationale (append-only)

## Rule of conflict
If anything disagrees, **constitution/contracts/requirements win**. Docs are explanatory only.
