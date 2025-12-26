# Homelab Stacks

Docker Compose–based infrastructure stacks intended to run on the Barbary NAS.

Rules:
- No secrets in git
- Each stack is self-contained
- Secrets are rendered at deploy-time (1Password)
- Persistent data must live in ZFS datasets
