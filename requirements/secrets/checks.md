# Secrets Management Checks

Validation checklist for secrets management compliance.

## Manual / CI Checks

- [ ] All production secrets stored in 1Password
- [ ] No plaintext secrets in git repository
- [ ] No secrets in git commit history
- [ ] ESO configured to pull from 1Password for Kubernetes workloads
- [ ] Docker Swarm `op inject` hydration services use `deploy.mode: replicated-job`
- [ ] Docker Swarm hydration jobs use `deploy.restart_policy.condition: none`
- [ ] One-shot hydration success validated as `0/1 (1/1 completed)` (not forced long-running `1/1`)
- [ ] GitHub Secrets usage limited to CI/CD bootstrapping
- [ ] All encrypted in-repo secrets documented with justification
- [ ] Secret scanning enabled in CI/CD pipeline
- [ ] Pre-commit hooks configured for secret detection
- [ ] Secret rotation procedures documented for all secret types
- [ ] Break-glass procedures available and tested

## Secret Scan Patterns

CI MUST scan for common secret patterns including:
- Private keys (RSA, Ed25519, ECDSA)
- API keys and tokens (AWS, Azure, GCP, GitHub, etc.)
- Database connection strings
- Password patterns in configuration
- OAuth client secrets
- JWT tokens

## Quarterly Review

- [ ] Review GitHub Secrets inventory and justifications
- [ ] Review encrypted in-repo secrets inventory
- [ ] Verify secret rotation procedures are current
- [ ] Test break-glass procedures
- [ ] Review and remove expired exceptions
