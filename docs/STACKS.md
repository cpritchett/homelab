# NAS stacks via TrueNAS Komodo

This repository ships Komodo-compatible Docker Swarm stacks. Deploy directly from Git via Komodo (no host-side deployment scripts for platform/application tiers).

## Layout
- `stacks/infrastructure/`: bootstrap-tier stacks (op-connect, komodo, caddy)
- `stacks/platform/`: platform services (auth, cicd, observability, backups, secrets)
- `stacks/docs/`: stack-specific operational runbooks

## Secrets
- Primary pattern: 1Password Connect + `secrets-init` + `op inject` templates for runtime hydration.
- Fallback pattern: Swarm external secrets for values that cannot use Connect runtime retrieval.
- Do not use legacy `op-export` pre-materialization workflows.

## Deployment (Komodo)
1. Add the repository in Komodo and configure stack path (`stacks/...`).
2. Configure any required pre-deploy validation hook (`scripts/validate-<stack>-setup.sh`).
3. Ensure prerequisite networks/secrets exist.
4. Deploy from Komodo and verify service health.

## References
- `docs/deployment/KOMODO_STACK_DEPLOYMENT.md`
- `docs/deployment/PHASE2_DEPLOYMENT_STEPS.md`
- `docs/governance/PRE-DEPLOYMENT-VALIDATION-POLICY.md`
