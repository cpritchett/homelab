# 20-harbor

Harbor registry behind the proxy stack.

## Required env
See `.env.example`.

## Networks
- App network: `harbor` (internal)
- Proxy network: `proxy_network` (external)

## Volumes / persistence (Barbary)
Recommended host paths under NVMe-backed pool:
- `/mnt/apps01/appdata/harbor/runtime/...`

## Ports
- No host ports should be published in this stack.
- Access should be via Caddy (00-proxy) reverse proxy.
