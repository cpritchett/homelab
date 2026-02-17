# Invariants
**Effective:** 2025-12-14  
**Authority:** Constitution [AMENDMENT-0003](../constitution/amendments/AMENDMENT-0003-contract-lifecycle.md)

These conditions must **always be true**. Any change that would violate an invariant is invalid.

**Adding/Amending:** See [AMENDMENT-0003](../constitution/amendments/AMENDMENT-0003-contract-lifecycle.md) for procedures.

## Network Identity Invariants

| Resource | Value | Notes |
|----------|-------|-------|
| Management VLAN | 100 | Fixed |
| Management CIDR | `10.0.100.0/24` | Fixed |
| Swarm Node VLAN | 5 | Fixed |
| Swarm Node CIDR | `10.0.5.0/24` | Fixed |
| Public zone | `hypyr.space` | Cloudflare-managed |
| Internal zone | `in.hypyr.space` | Local DNS only |

## WAN Constraints

| Resource | Capacity | Stability | Notes |
|----------|----------|-----------|-------|
| Primary WAN (DOCSIS) Upload | 20-30 Mbps | Frequent instability | Residential cable |
| Primary WAN (DOCSIS) Download | 1 Gbps | Frequent instability | Residential cable |
| Secondary WAN (5G) | Variable | Variable | Failover only |

## Storage Configuration Invariants

**Storage System:** TrueNAS ZFS (host paths) + NFS exports to swarm nodes

NFS mounts on swarm nodes:
- `/mnt/apps01/appdata` — application configuration data
- `/mnt/data01/data` — media and bulk data

## Hardware Constraints

| Resource | Quantity | Notes |
|----------|----------|-------|
| Docker Swarm managers | 2 | Proxmox VMs (ching, angre) |
| Docker Swarm workers | 2 | Bare metal (lorcha, dhow) |
| Primary NAS | 1 | 45Drives HL15 (TrueNAS, ~100TB, brownfield) |
| Secondary NAS | 1 | Synology DS918+ (DSM, S3 via Garage, brownfield) |

## Access Invariants

1. **Management network has no Internet egress by default**
   - Egress may be allowed only via explicit allow rules documented in an ADR

2. **Only Mgmt-Consoles may initiate traffic into Management**
   - No other device class may originate connections to Management VLAN

3. **External ingress is Cloudflare Tunnel only**
   - No port forwards
   - No WAN-exposed listeners
   - No "temporary" openings without documented exception

4. **Overlay agents are prohibited on Management VLAN devices**
   - Overlay is transport for trusted humans, not management infrastructure

5. **No management infrastructure operates on secondary networks**

## DNS Invariants

1. **No additional internal suffixes** (`.lan`, `.local`, `.home` are prohibited)

2. **No split-horizon overrides** (public FQDN must not resolve to internal target)

3. **Zone dependency boundaries**:
   - Internal-only services MUST NOT depend on `hypyr.space` resolution
   - Public services MUST NOT depend on `in.hypyr.space` resolution

## Repository Structure Invariants

1. **Root-level files are exhaustively enumerated**
   - Only files explicitly listed in `scripts/enforce-root-structure.sh` may exist in repository root
   - No arbitrary documentation, summaries, or scratch files in root

2. **Markdown files MUST be on allowlist** (see ADR-0025)
   - Only `.md` files explicitly permitted by location/name pattern are allowed
   - Violations blocked by `scripts/enforce-markdown-allowlist.sh` gate
   - Arbitrary summaries, notes, plans (outside `specs/NNN-*/`) prohibited
   - Permitted locations:
     - Root: `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `agents.md`
     - `docs/adr/ADR-NNNN-*.md` (append-only)
     - `docs/`, `docs/governance/`, `docs/operations/`
     - `docs/guides/`, `docs/reference/`, `docs/troubleshooting/`
     - `ops/README.md`, `ops/runbooks/`
     - `requirements/*/spec.md`, `requirements/*/checks.md`
     - `specs/NNN-*/spec.md`, `specs/NNN-*/plan.md`, `specs/NNN-*/research.md`, `specs/NNN-*/data-model.md`, `specs/NNN-*/quickstart.md`, `specs/NNN-*/contracts/`, `specs/NNN-*/checklists/`, `specs/NNN-*/tasks.md`
     - `infra/README.md`, `infra/<domain>/README.md`
     - `ansible/README.md`, `opentofu/README.md`

3. **Specification placement is constrained** (see ADR-0026)
   - Canonical specs **only** under `requirements/<domain>/spec.md`
   - Non-canonical/operational specs **only** under `specs/NNN-<slug>/spec.md`
   - Enforced by `scripts/check-spec-placement.sh` and CI gate wiring

4. **Documentation must be properly located**:
   - Architecture decisions → `docs/adr/`
   - General documentation → `docs/`
   - Operational documentation → `ops/runbooks/`
   - Deployment guides → `docs/guides/`
   - Reference docs → `docs/reference/`
   - Implementation → `infra/<domain>/`

5. **Deployment targets are separated by directory**:
   - Docker Swarm stacks → `stacks/` (Compose files, deployed via Komodo)
   - Node configuration → `ansible/` (Ansible playbooks and roles)
   - VM provisioning → `opentofu/` (Proxmox VM creation)
   - Infrastructure config → `infra/` (DNS, Cloudflare, UniFi)

6. **CI enforcement is mandatory**
   - All structural rules MUST be validated in CI (`.github/workflows/guardrails.yml`)
   - PRs violating structure MUST be blocked

7. **NAS stacks are Komodo-managed**
   - NAS/non-Kubernetes stacks are deployed from this repository via TrueNAS Komodo
   - No `stacks/registry.toml` or host-side deploy scripts are required or permitted
   - Each stack directory must be self-contained (compose file + `.env.example`)

## Secrets Management Invariants

1. **1Password is the single source of truth**
   - All production secrets MUST be stored in 1Password
   - No secrets in git history, commit messages, or unencrypted files

2. **Docker Swarm secrets MUST use 1Password Connect pattern**
   - Stacks use `secrets-init` containers with `op inject`
   - Shared Swarm secret `op_connect_token` for all stacks
   - Secrets hydrated at startup, never pre-materialized to host disk

3. **Plaintext secrets on disk are prohibited**
   - Exception: 1Password Connect credentials file at `/mnt/apps01/secrets/op/1password-credentials.json` (600 permissions, never committed)

4. **Secret scanning MUST be enabled**
   - Pre-commit hooks scan for secrets
   - CI gates block merges with detected secrets
   - Gitleaks or equivalent tool required

5. **World-readable permissions on secrets directories are prohibited**
   - `chmod 777` or `chmod 666` on any directory or file containing secrets, credentials, or sensitive configuration is a hard stop
   - Secrets directories MUST be owned by the writing process UID (e.g., 999:999 for 1Password op) with mode 750 or stricter
   - Secret files MUST have mode 644 or stricter (644 when consumed by non-root services, 600 when consumed by root only)
   - Pre-deploy validation scripts MUST enforce correct ownership and permissions
