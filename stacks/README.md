# Homelab Stacks

Docker Compose–based infrastructure stacks intended to run on the homelab NAS systems documented in `requirements/compute/spec.md` (e.g., 45Drives HL15 (TrueNAS) and Synology DS918+).

Rules:
- No secrets in git
- Each stack is self-contained
- Secrets are rendered at deploy-time (1Password)
- Persistent data must live in ZFS datasets
