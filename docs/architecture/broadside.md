# Broadside Recovery Node

Broadside is a small NixOS recovery node. It is intentionally narrow in scope and exists to reduce barbary's blast radius, not to replace barbary as a general platform host.

## Role

Broadside exists to provide:

- operator access during outages
- a static runbook site
- a read-only mirror of critical repos and configuration
- a secondary resolver for recovery workflows
- a restore target for selected lightweight recovery services

Broadside does not exist to provide:

- Authentik
- PostgreSQL
- Komodo workload hosting
- a full observability stack
- general Docker Swarm placement
- a second always-on authority plane for the LAN

## Operating Model

### Day To Day

In normal operation, barbary remains the primary stateful host and the existing LAN control points remain primary.

Broadside runs continuously, but mostly as a passive utility endpoint:

- `ssh` and Tailscale provide operator access
- `unbound` acts as a forwarding and caching resolver
- Caddy serves static runbooks and the read-only mirror
- the mirror always includes the exact repo snapshot deployed with broadside itself
- live mirror refreshes should target internal services first, not external GitHub
- optional recovery services stay disabled unless needed

Broadside should not shadow normal LAN service names, should not advertise itself as the default resolver for the LAN, and should not transparently take over mutable authority services.

### Recovery

When barbary is unavailable, broadside becomes the operator's recovery anchor:

- reach broadside over LAN or Tailscale
- use the runbook site and mirrored repo to execute recovery
- query broadside's local resolver directly from operator systems or selected recovery clients
- restore selected services onto broadside only when they are operationally required

This model is intentionally operator-driven. Promotion is explicit, scoped, and documented to avoid split-brain behavior.

## DNS Interaction

`hypyr.space` is not the LAN's internal authority zone. Day-to-day name resolution for the LAN remains on the router or upstream DNS.

Broadside's DNS role is therefore limited:

- Unbound forwards upstream to the router's DNS service
- Broadside may host a very small set of local recovery records for its own services
- Broadside must not override the normal LAN zone wholesale
- Broadside must not override public names to bypass existing trust boundaries

### Recommended Naming

Prefer explicit recovery names over shadowing primary names:

- `broadside.in.hypyr.space`
- `runbooks-broadside.in.hypyr.space`
- `mirror-broadside.in.hypyr.space`
- `ca-broadside.in.hypyr.space`

These names are safe to publish in router DNS when desired because they describe a separate recovery endpoint rather than pretending to be the primary service.

## PKI Interaction

Broadside should not run an active or semi-automatic hot-standby issuer in v1.

The better pattern for this homelab is:

- one authoritative Step-CA service on barbary during normal operation
- broadside permanently trusts the same root CA
- broadside keeps recovery materials, runbooks, and restore automation
- if PKI service is needed during a barbary outage, Step-CA is restored onto broadside from backup

This avoids:

- dual-writer CA state
- diverging issuer databases
- ambiguous revocation state
- hidden failover behavior during an incident

### Broadside PKI Responsibilities

Broadside should keep:

- the trusted root certificate
- a recent backup archive of the Step-CA state directory
- a restore script and verification script
- a documented recovery hostname for restored CA service

Broadside should not attempt transparent PKI failover. The operator should explicitly restore and verify the service before repointing any clients.

## Service Categories

### Safe to Run Continuously

- SSH
- Tailscale
- Unbound forwarding/cache
- Caddy static site
- read-only repo mirror

These are either stateless, read-only, or low-conflict.

### Safe to Restore Manually When Needed

- Step-CA
- dnsmasq + Matchbox
- Uptime Kuma

These are useful in recovery but should be activated deliberately.

### Not Appropriate for Broadside

- Authentik
- PostgreSQL
- Forgejo primary
- Komodo control plane
- full Prometheus, Loki, Grafana stack

These are either too stateful, too heavy, or too central to operate as ad hoc failover services on the recovery node.

## Failure Boundaries

### If Barbary Is Healthy

- broadside stays passive
- no client cutover is required
- no service authority moves
- barbary continues to host the primary PXE path; broadside's installer assets are generated from this repo into the repo-served PXE asset tree

### If Barbary Is Degraded but Reachable

- broadside provides documentation and diagnostics
- operators may test broadside DNS and mirror endpoints directly
- primary state remains on barbary

### If Barbary Is Unavailable

- broadside provides the operator access path
- broadside can answer recovery-only DNS queries for its own services
- Step-CA can be restored onto broadside if internal certificate issuance is required
- PXE services can be promoted later if PXE independence is needed

## Implementation Notes

- Keep the broadside NixOS config shallow and readable
- Prefer native NixOS services for core functions
- Use containers only where the native NixOS option is not worth the complexity tradeoff
- Keep persistent state under explicit directories on the recovery ZFS pool
- Prefer manual promotion with helper scripts over background automation for authority services

## Related Documentation

- [Disaster Recovery](../runbooks/disaster-recovery.md)
- [Broadside Recovery Runbook](../runbooks/broadside-recovery.md)
- [Secrets Management](./secrets.md)
- [Storage Architecture](./storage.md)
