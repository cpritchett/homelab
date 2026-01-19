# 00-proxy (Caddy)

Komodo-managed reverse proxy stack for `*.in.hypyr.space`.

## Required env
See `.env.example`.

## Networks
- `proxy_network` must exist (external Docker network).

## Volumes (Barbary)
- `/mnt/apps01/appdata/proxy/caddy-data`
- `/mnt/apps01/appdata/proxy/caddy-config`

## Notes
- This stack should be deployed before any app stacks that attach to `proxy_network`.
