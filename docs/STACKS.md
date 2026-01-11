# Barbary NAS stacks (GitHub-driven, no secrets in git)

## Layout
- `stacks/proxy`: Caddy + docker-socket-proxy (terminates 80/443)
- `stacks/harbor`: Harbor (no host ports; joins `proxy_network` and is routed by Caddy labels)

## 1Password secrets
- Each stack has `.env.tpl` containing `op://` references.
- Run `./render-env.sh` to render `.env` locally (never commit `.env`).

## On the NAS
- The deployment entrypoint is `stacks/_bin/sync-and-deploy` (uses sparse checkout).
- TrueNAS should run the init/cron script that calls that entrypoint.

## Deployment order
- Stack order is defined by `stacks/registry.toml` (dependency-based).

## Notes
- Harbor expects certain config dirs under `/mnt/apps01/appdata/harbor/runtime/*`.
  If you previously deployed Harbor using the official installer tarball (offline installer),
  you can reuse the generated `common/config/*` from that installation by copying it into
  the runtime config paths mounted by this stack (see the Harbor compose file for the exact
  volume mappings). For details on obtaining and using the installer, see the official docs:
  https://goharbor.io/docs/latest/install-config/
