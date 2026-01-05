# Barbary NAS stacks (GitHub-driven, no secrets in git)

## Layout
- `stacks/00-proxy`: Caddy + docker-socket-proxy (terminates 80/443)
- `stacks/20-harbor`: Harbor (no host ports; joins `proxy_network` and is routed by Caddy labels)

## 1Password secrets
- Each stack has `.env.tpl` containing `op://` references.
- Run `./render-env.sh` to render `.env` locally (never commit `.env`).

## On the NAS
- The deployment entrypoint is `bin/sync-and-deploy` (uses sparse checkout).
- TrueNAS should run the init/cron script that calls that entrypoint.

## Notes
- Harbor expects certain config dirs under `/mnt/apps01/appdata/harbor/runtime/*`.
  If you came from the Harbor installer tarball, reuse that generated `common/config/*`
  by copying it into the runtime config paths referenced by the compose.
