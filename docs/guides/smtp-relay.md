# SMTP Relay

Use `stacks/platform/mail/smtp-relay/compose.yaml` to provide one internal SMTP submission point for homelab services.

## What it does

- Runs a lightweight `msmtpd` relay on the internal swarm network `platform_smtp_relay`
- Uses Resend SMTP as the upstream transactional provider
- Stores only the runtime sending credential in 1Password
- Lets services send mail to `smtp-relay:2500` instead of configuring external SMTP providers individually
- Keeps sender identities narrow under `tx.hypyr.space`

## 1Password item

This stack uses `homelab/smtp-relay` for runtime sending only:

- `RESEND_RUNTIME_API_KEY`

The remaining relay behavior is inferred in git:

- `SMTP_HOST=smtp.resend.com`
- `SMTP_PORT=587`
- `SMTP_TLS=off`
- `SMTP_STARTTLS=on`
- `SMTP_AUTH=on`
- `SMTP_USER=resend`
- `SMTP_FROM=system@tx.hypyr.space`
- `SMTP_ALLOW_FROM_OVERRIDE=on`
- `SMTP_SET_FROM_HEADER=auto`

This follows the bootstrap pattern:

- infrastructure/provider automation should use a separate Resend account key
- application and SMTP sending should use the runtime key only

## Sender addresses

Keep senders limited to:

- `alerts@tx.hypyr.space`
- `auth@tx.hypyr.space`
- `system@tx.hypyr.space`
- `noreply@tx.hypyr.space`

## Runtime values

- Relay hostname on the shared network: `smtp-relay`
- Relay port: `2500`
- Relay network: `platform_smtp_relay`
- Relay container domain setting: `smtp-relay.in.hypyr.space`

The relay is internal-only. It has no Caddy labels and no published ports, so other services can only use it if they are attached to `platform_smtp_relay`.

## Git-managed consumers already wired

These stacks are already configured in git to use the relay and already attach to `platform_smtp_relay`:

| Service | URL | Stack path | Evidence |
| --- | --- | --- | --- |
| Authentik | `https://auth.in.hypyr.space` | `stacks/platform/auth/authentik` | sends as `auth@tx.hypyr.space`; `smtp_relay` network in `compose.yaml` |
| Forgejo | `https://git.in.hypyr.space` | `stacks/platform/cicd/forgejo` | sends as `noreply@tx.hypyr.space`; `smtp_relay` network in `compose.yaml` |
| Grafana | `https://grafana.in.hypyr.space` | `stacks/platform/monitoring` | sends as `alerts@tx.hypyr.space`; `smtp_relay` network in `compose.yaml` |

These are the only consumers currently reachable from the relay by repo-managed configuration.

## Manual follow-up candidates

Several other deployed applications likely support SMTP or email notifications, but the repo does not currently express SMTP settings for them.

That means the operator workflow for these apps is usually:

1. Ensure the service is attached to `platform_smtp_relay`
2. Redeploy the stack
3. Configure the app's SMTP settings in its UI

### Candidates by stack

| Service | URL | Stack path | Current state | Notes |
| --- | --- | --- | --- | --- |
| n8n | `https://automation.in.hypyr.space` | `stacks/platform/automation/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`, but no SMTP env wiring is present in `n8n.env.template` |
| Uptime Kuma | `https://status.in.hypyr.space` | `stacks/platform/observability/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; configure notifications in the UI |
| Woodpecker CI | `https://ci.in.hypyr.space` | `stacks/platform/cicd/woodpecker/compose.yaml` | needs product-specific review | No SMTP-related settings are present in `env.template`; treat as a follow-up integration rather than a drop-in candidate |
| Sonarr | `https://sonarr.in.hypyr.space` | `stacks/application/media/core/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; the repo still only manages API keys and DB settings |
| Radarr | `https://radarr.in.hypyr.space` | `stacks/application/media/core/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; configure notifications in the UI |
| Prowlarr | `https://prowlarr.in.hypyr.space` | `stacks/application/media/core/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; configure notifications in the UI |
| SABnzbd | `https://sabnzbd.in.hypyr.space` | `stacks/application/media/core/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; SMTP remains app-managed |
| Bazarr | `https://bazarr.in.hypyr.space` | `stacks/application/media/support/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; no SMTP wiring is present in repo-managed config |
| Tautulli | `https://tautulli.in.hypyr.space` | `stacks/application/media/support/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; configure notifications in the UI |
| Seerr | `https://requests.in.hypyr.space` | `stacks/application/media/support/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; useful for request/approval mail if enabled in-app |
| Wizarr | `https://invite.in.hypyr.space` | `stacks/application/media/support/compose.yaml` | UI/manual candidate | Attached to `platform_smtp_relay`; invitation/onboarding mail remains app-managed |

### Not currently good relay targets

| Service | URL | Reason |
| --- | --- | --- |
| Plex | `https://plex.in.hypyr.space` | No repo-managed SMTP surface is present; notifications are typically account/cloud driven rather than local relay driven |
| Jellyfin | `https://jellyfin.in.hypyr.space` | No SMTP wiring is represented in repo; treat as a product-specific follow-up if email becomes important |
| qBittorrent | n/a in production | Stack exists separately, but it is not part of the current deployed path covered by this guide |

## Standard onboarding workflow for a new consumer

### If the service is repo-managed by env vars

Use Authentik, Forgejo, and Grafana as the reference pattern:

1. Add the service to the external network `platform_smtp_relay`
2. Add the app's SMTP env vars to its `*.env.template`
3. Set the host to `smtp-relay`
4. Set the port to `2500`
5. Set a sender under `tx.hypyr.space` that matches the app's purpose
6. Redeploy the stack
7. Send a test email from the application

### If the service is configured through its own UI

1. Ensure the stack or service is attached to `platform_smtp_relay`
2. Redeploy the stack
3. Open the app UI and find its notification or mail settings
4. Configure:
   - host: `smtp-relay`
   - port: `2500`
   - TLS/SSL: disabled unless that product specifically requires otherwise
   - authentication: off unless a product cannot submit anonymously
   - from address: choose one of `alerts@tx.hypyr.space`, `auth@tx.hypyr.space`, `system@tx.hypyr.space`, or `noreply@tx.hypyr.space`
5. Send a test email from the app UI

If the app cannot join `platform_smtp_relay`, do not point it at the relay by name. The relay is not exposed publicly.

## Deployment order

1. Run `scripts/validate-smtp-relay-setup.sh`
2. Deploy `stacks/platform/mail/smtp-relay`
3. Redeploy git-managed consumers so they can join `platform_smtp_relay`
4. For any new manual consumer, make sure its stack has relay network access, then redeploy, then configure the app UI

## Operator checklist

Use this checklist when extending SMTP coverage:

1. Confirm the app actually needs email and that email is worth centralizing
2. Check whether the repo already has a first-class SMTP env surface for that app
3. If not, decide whether the app should be:
   - fully repo-managed
   - UI-managed after network attachment
   - skipped as not worth the complexity
4. Ensure the stack is attached to `platform_smtp_relay`
5. Redeploy
6. Configure the app
7. Send a test message and verify relay logs

## Notes

- Today, only Authentik, Forgejo, and Grafana are fully wired to send through the relay by git-managed configuration.
- Several additional stacks are now attached to `platform_smtp_relay`, but they still require app-level SMTP configuration in their own UI before they will send mail.
- The repo evidence for those candidates is their deployment and public URL; the actual SMTP capability is inferred from normal product behavior unless SMTP settings are explicitly present in git-managed config.
- This implementation intentionally uses Resend SMTP. Direct Resend API senders or webhook receivers can be added later without changing the legacy SMTP relay pattern.
