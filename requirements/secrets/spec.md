# Secrets Management Requirements
**Effective:** 2025-12-14

## Definition

Secrets include:
- API keys and tokens
- Passwords and passphrases
- Private keys and certificates
- Database connection strings
- Service account credentials
- OAuth client secrets
- Encryption keys

## Primary source of truth

**1Password is the authoritative secrets store** for all homelab infrastructure.

## Storage hierarchy

Secrets MAY be stored in the following locations, in order of preference:

1. **1Password** (primary)
   - All production secrets MUST be stored in 1Password
   - 1Password acts as the single source of truth

2. **External Secrets Operator (ESO)** (Kubernetes integration)
   - ESO MUST fetch secrets from 1Password for Kubernetes workloads
   - ESO configuration is the preferred method for injecting secrets into Kubernetes
   - ESO manifests themselves contain no secret values, only references

3. **GitHub Secrets** (CI/CD bootstrapping only)
   - ONLY for bootstrapping CI/CD pipelines
   - ONLY for secrets required before 1Password/ESO are available
   - Must be documented with justification

4. **Encrypted in-repo** (bootstrapping only)
   - ONLY for initial infrastructure bootstrap scenarios
   - MUST use industry-standard encryption (e.g., SOPS, age, sealed-secrets)
   - MUST be documented with justification
   - MUST include key rotation procedures

## Prohibitions

1. **Plaintext secrets in repositories are PROHIBITED**
   - No secrets in source code
   - No secrets in configuration files committed to git
   - No secrets in documentation or comments

2. **Secrets in commit history are PROHIBITED**
   - Even if later removed, secrets in git history require repository remediation
   - Use BFG Repo-Cleaner or similar if secrets are accidentally committed

3. **Long-lived static secrets are DISCOURAGED**
   - Prefer short-lived tokens and credential rotation
   - Document rotation procedures for all secrets

## CI/CD requirements

1. **Automated secret scanning MUST be enabled**
   - Pre-commit hooks SHOULD scan for secrets
   - CI pipelines MUST scan for secrets on all PRs
   - Failed secret scans MUST block merges

2. **Secret rotation procedures MUST be documented**
   - Each secret type MUST have a documented rotation procedure
   - Break-glass procedures MUST be available for emergency rotation

## Exception handling

Exceptions to these requirements (e.g., temporary secrets for development) MUST:
- Be documented in an ADR
- Include an expiration date or trigger for removal
- Be reviewed quarterly

## Rationale

Secrets management is critical for infrastructure security. Centralizing secrets in 1Password with controlled access patterns (ESO for Kubernetes, GitHub Secrets for CI/CD bootstrap only) reduces attack surface and simplifies auditing.

Prohibiting plaintext secrets in repositories prevents accidental exposure and credential leakage through git history.

See: [ADR-0004](../../docs/adr/ADR-0004-secrets-management.md)

## Agent Governance

For agent procedures on governance and compliance, see: [ADR-0005](../../docs/adr/ADR-0005-agent-governance-procedures.md)
