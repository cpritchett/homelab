# Docs
This folder contains explanatory content—*why* decisions were made.

**This content is not normative.** If there is any conflict between docs and `requirements/`, `contracts/`, or `constitution/`, the normative content wins.

## Contents

- [rationale.md](rationale.md) — High-level purpose
- [glossary.md](glossary.md) — Key terminology
- [adr/](adr/) — Architectural Decision Records
- [architecture/](architecture/) — System architecture and diagrams
- [guides/](guides/) — Bootstrap, platform deployment, and service-specific guides
- [reference/](reference/) — Label patterns, permissions, Renovate configuration
- [runbooks/](runbooks/) — Operational procedures
- [troubleshooting/](troubleshooting/) — Known issues and fixes
- [risk/](risk/) — Risk register
- [governance/](governance/) — Repository structure and deployment policies
- [security/](security/) — Security documentation

## Architecture

System architecture documentation with Mermaid diagrams:

- [Overview](architecture/overview.md) — Infrastructure tiers, node topology, technology stack
- [Networking](architecture/networking.md) — Overlay networks, ingress flow, DNS
- [Storage](architecture/storage.md) — TrueNAS mounts, backup strategy, UID/GID conventions
- [Secrets](architecture/secrets.md) — 1Password Connect, secret injection pattern
- [Deployment Flow](architecture/deployment-flow.md) — Komodo ResourceSync, bootstrap sequence

## Node Configuration

Swarm node configuration and hardening is managed by Ansible. See:

- [ansible/README.md](../ansible/README.md) — Architecture, roles, and quick reference
- [runbooks/ansible-node-bootstrap.md](runbooks/ansible-node-bootstrap.md) — Bootstrap runbook
- [runbooks/ansible-hardening.md](runbooks/ansible-hardening.md) — Hardening runbook
- [runbooks/ansible-day2-operations.md](runbooks/ansible-day2-operations.md) — Day-2 operations
