# ADR-0004: Secrets Management with 1Password

## Status
Accepted

## Context
Homelab infrastructure requires secure storage and distribution of secrets (API keys, passwords, certificates). Secrets scattered across multiple locations or stored in plaintext in repositories create security risks and operational complexity.

## Decision
Establish 1Password as the primary source of truth for all secrets with the following distribution pattern:
- **1Password**: Primary storage for all production secrets
- **External Secrets Operator (ESO)**: Kubernetes integration pulling from 1Password
- **GitHub Secrets**: Limited to CI/CD bootstrapping only
- **Encrypted in-repo**: Only for initial infrastructure bootstrap with documented justification

Plaintext secrets in repositories are prohibited. Automated secret scanning must be enabled in CI/CD pipelines.

## Consequences
### Positive
- Single source of truth simplifies secret management and auditing
- ESO integration provides secure, automated secret injection into Kubernetes
- Automated scanning prevents accidental secret commits
- Clear hierarchy reduces confusion about where secrets belong

### Negative
- Requires 1Password subscription and ESO setup
- Initial migration effort for existing secrets
- Dependency on 1Password availability for operations

### Neutral
- GitHub Secrets and encrypted in-repo options provide escape hatches for bootstrapping
- Requires documentation for each exception to standard pattern

## Links
- [requirements/secrets/spec.md](../../requirements/secrets/spec.md)
- [External Secrets Operator](https://external-secrets.io/)
- [1Password](https://1password.com/)
