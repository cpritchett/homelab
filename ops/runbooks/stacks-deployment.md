# Runbook: NAS Stacks Deployment (TrueNAS)

**Scope:** Docker Compose stacks deployed on NAS hosts via the homelab repo.

## Summary

Stacks are deployed from this repo via TrueNAS **Komodo**. Each stack is pulled directly from
GitHub and deployed as a Compose app; no registry file or host-side deployment scripts are used.

## Prerequisites

- NAS host is LAN-only (no WAN exposure).
- Docker installed and running on the NAS.
- External Docker network exists (run once):
  - `docker network create proxy_network`
## Komodo deployment flow

1) In TrueNAS Komodo, add a new app from GitHub and point to the stack path (e.g., `stacks/proxy`).
2) Populate env/secret values using the stack's `.env.example` as a guide.
3) Ensure shared prerequisites like `proxy_network` exist before deploying dependent stacks (e.g., `authentik` expects the proxy network).
4) Deploy via Komodo UI. Repeat for additional stacks.

## Troubleshooting

### Check rendered env files

### Docker status

```bash
sudo docker compose ps
sudo docker logs caddy --tail=200
sudo docker logs harbor-core --tail=200
```
