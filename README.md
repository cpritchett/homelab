# hypyr homelab

This repo captures **governing specifications** for homelab infrastructure with strict agent contracts.

## Hierarchy of Authority

Conflicts are resolved by precedence (highest first):

1. **`constitution/`** — Immutable principles; cannot be overridden
2. **`contracts/`** — Agent operating rules; must comply with constitution
3. **`requirements/`** — Domain specs; must comply with constitution and contracts
4. **`docs/`** — Explanatory only; no normative authority
5. **`infra/` + `ops/`** — Implementation; must satisfy requirements

## Quick links

### Normative (what must be true)
- Constitution: [`constitution/constitution.md`](constitution/constitution.md)
- Agent contract: [`contracts/agents.md`](contracts/agents.md)
- Hard-stops: [`contracts/hard-stops.md`](contracts/hard-stops.md)
- Invariants: [`contracts/invariants.md`](contracts/invariants.md)
- Compute spec: [`requirements/compute/spec.md`](requirements/compute/spec.md)
- DNS spec: [`requirements/dns/spec.md`](requirements/dns/spec.md)
- Ingress spec: [`requirements/ingress/spec.md`](requirements/ingress/spec.md)
- Management spec: [`requirements/management/spec.md`](requirements/management/spec.md)
- Overlay spec: [`requirements/overlay/spec.md`](requirements/overlay/spec.md)
- Secrets spec: [`requirements/secrets/spec.md`](requirements/secrets/spec.md)
- Storage spec: [`requirements/storage/spec.md`](requirements/storage/spec.md)
- Tooling spec: [`requirements/tooling/spec.md`](requirements/tooling/spec.md)
- Workflow spec: [`requirements/workflow/spec.md`](requirements/workflow/spec.md)

### Explanatory (why)
- Rationale: [`docs/platform/rationale.md`](docs/platform/rationale.md)
- Glossary: [`docs/governance/glossary.md`](docs/governance/glossary.md)
- ADRs: [`docs/adr/`](docs/adr/)
- Risk register: [`docs/governance/risk/risk-register.md`](docs/governance/risk/risk-register.md)

### Spec-Kit
- `.specify/` — Spec-Kit compatibility layer for AI agents

## Change discipline
- Update `requirements/` or `contracts/` when rules change
- Add an ADR in `docs/adr/` for major decisions or reversals
- Constitutional amendments require `constitution/amendments/`

## Security guardrails
- Install git hooks once: `mise run hooks:install`
- Scan staged changes locally: `mise run security:scan:staged`
- Full repo scan: `mise run security:scan:repo`
- CI required check: `pii_secrets_gate` (see `.github/workflows/security-pii-secrets.yml`)
- Policy/details: `docs/governance/security/pii-and-secrets.md`
