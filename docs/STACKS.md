# NAS stacks via TrueNAS Komodo

This repository now ships only Komodo-compatible stacks. Deploy them directly from GitHub using the TrueNAS Komodo app (no registry, no host-side scripts).

## Layout
- `stacks/proxy`: Caddy reverse proxy + docker-socket-proxy on `proxy_network` (external network must exist).
- `stacks/authentik`: Authentik with bundled Postgres + Redis, routed through the proxy.

## Secrets / env
- Each stack has a `.env.example` documenting required variables.
- Set values in Komodo's environment/secret UI (1Password CLI templating via `op inject` and `.env.tpl` files are no longer used).

## Deployment (TrueNAS Komodo)
1. Add the homelab repo in Komodo and select the stack directory (e.g., `stacks/proxy`).
2. Provide env/secret values from `.env.example`.
3. Ensure shared prerequisites (e.g., external Docker network `proxy_network`) exist before deploying dependent stacks.
4. Deploy via Komodo. Repeat for additional stacks.

## Notes
- Registry-based ordering (`stacks/registry.toml`) and helper scripts (`stacks/_bin/*`, `_system/*`) have been removed.
- Keep stack directories self-contained: `compose.yaml` + `.env.example` only.
