# Requirements (Normative)

This folder contains **normative domain requirements**. These are enforceable constraints.

## Domains
- `compute/`
  - `spec.md` — hardware and compute infrastructure requirements
  - `checks.md` — validation criteria
- `dns/`
  - `spec.md` — DNS intent requirements
  - `checks.md` — validation criteria
- `ingress/`
  - `spec.md` — Cloudflare Tunnel-only ingress requirements
  - `checks.md` — validation criteria
- `management/`
  - `spec.md` — management network requirements
  - `checks.md` — validation criteria
- `overlay/`
  - `spec.md` — overlay networking requirements
  - `checks.md` — validation criteria
- `secrets/`
  - `spec.md` — secrets management requirements
  - `checks.md` — validation criteria
- `storage/`
  - `spec.md` — persistent storage requirements (Longhorn, TrueNAS, S3)
  - `checks.md` — validation criteria
- `bootstrap/`
  - `spec.md` — bare-metal and GitOps bootstrap requirements
  - `checks.md` — validation criteria
- `tooling/`
  - `spec.md` — developer tooling stack requirements
  - `checks.md` — validation criteria
- `workflow/`
  - `spec.md` — git workflow and commit convention requirements
  - `checks.md` — validation criteria

## Authority
If anything conflicts, precedence is:
1. `constitution/`
2. `contracts/`
3. `requirements/`
4. `docs/` (explanatory only)

## Agent Compliance
Agents must follow governance procedures when making changes to any domain.

See: [ADR-0005](../docs/adr/ADR-0005-agent-governance-procedures.md)
