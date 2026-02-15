# hypyr homelab

This repo captures **governing specifications** for homelab infrastructure with strict agent contracts.

## Hierarchy of Authority

Conflicts are resolved by precedence (highest first):

1. **`constitution/`** — Immutable principles; cannot be overridden
2. **`contracts/`** — Agent operating rules; must comply with constitution
3. **`requirements/`** — Domain specs; must comply with constitution and contracts
4. **`docs/`** — Explanatory only; no normative authority
5. **`stacks/` + `ansible/` + `opentofu/` + `ops/`** — Implementation; must satisfy requirements

## Quick links

### Normative (what must be true)
- Constitution: [`constitution/constitution.md`](constitution/constitution.md)
- Agent contract: [`contracts/agents.md`](contracts/agents.md)
- Hard-stops: [`contracts/hard-stops.md`](contracts/hard-stops.md)
- Invariants: [`contracts/invariants.md`](contracts/invariants.md)
- DNS spec: [`requirements/dns/spec.md`](requirements/dns/spec.md)
- Ingress spec: [`requirements/ingress/spec.md`](requirements/ingress/spec.md)
- Management spec: [`requirements/management/spec.md`](requirements/management/spec.md)
- Overlay spec: [`requirements/overlay/spec.md`](requirements/overlay/spec.md)
- Secrets spec: [`requirements/secrets/spec.md`](requirements/secrets/spec.md)
- Storage spec: [`requirements/storage/spec.md`](requirements/storage/spec.md)
- Tooling spec: [`requirements/tooling/spec.md`](requirements/tooling/spec.md)
- Workflow spec: [`requirements/workflow/spec.md`](requirements/workflow/spec.md)

### Infrastructure
- Docker Swarm stacks: [`stacks/`](stacks/)
- Ansible (node config & hardening): [`ansible/`](ansible/)
- OpenTofu (Proxmox VMs): [`opentofu/`](opentofu/)
- Komodo resources: [`komodo/`](komodo/)
- Runbooks: [`docs/runbooks/`](docs/runbooks/)

### Explanatory (why)
- Architecture: [`docs/architecture/`](docs/architecture/)
- Rationale: [`docs/rationale.md`](docs/rationale.md)
- Glossary: [`docs/glossary.md`](docs/glossary.md)
- ADRs: [`docs/adr/`](docs/adr/)
- Risk register: [`docs/risk/risk-register.md`](docs/risk/risk-register.md)

## Change discipline
- Update `requirements/` or `contracts/` when rules change
- Add an ADR in `docs/adr/` for major decisions or reversals
- Constitutional amendments require `constitution/amendments/`

## Security guardrails
- Install git hooks once: `mise run hooks:install`
- Scan staged changes locally: `mise run security:scan:staged`
- Full repo scan: `mise run security:scan:repo`
- CI required check: `pii_secrets_gate` (see `.github/workflows/security-pii-secrets.yml`)
- Policy/details: `docs/security/pii-and-secrets.md`
