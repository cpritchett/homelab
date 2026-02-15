# ADR-0038: Internal PKI with Smallstep CA

**Status:** Accepted
**Date:** 2026-02-14
**Relates to:** ADR-0034 (Label-Driven Infrastructure), ADR-0002 (Tunnel-Only Ingress)
**Resolves:** [#135 — Replace insecure_tls on Periphery connections](https://github.com/cpritchett/homelab/issues/135)

## Context

The homelab has three distinct TLS needs:

1. **Browser-facing services** behind Caddy (`*.in.hypyr.space`) — users expect trusted certificates to avoid browser warnings.
2. **Service-to-service communication** (Komodo Core → Periphery, future inter-node links) — needs encryption and identity verification, but no browser trust required.
3. **Caddy's current dual role** — it handles both Let's Encrypt ACME certs (via Cloudflare DNS-01 challenge) and `tls internal` self-signed certs via its built-in PKI.

The problem: Caddy's built-in PKI is tightly coupled to its own proxy and cannot issue certificates for services that Caddy doesn't proxy. Komodo Periphery enables `PERIPHERY_SSL_ENABLED: 'true'` but generates its own untrusted self-signed certificate. Komodo Core has no way to verify it, so all five server connections in `komodo/resources.toml` set `insecure_tls = true`, disabling TLS verification entirely. This leaves the management plane vulnerable to MITM attacks.

## Decision

Adopt a **two-CA model**:

| CA | Scope | Cert Type | Trust Boundary |
|----|-------|-----------|----------------|
| **Caddy + Let's Encrypt** | Services proxied by Caddy | ACME (publicly trusted) | Browsers, external clients |
| **Smallstep CA (step-ca)** | Everything else | Internal CA (privately trusted) | Internal services only |

### Caddy (unchanged)

Caddy continues to handle TLS for all browser-facing services it proxies:

- `*.in.hypyr.space` services get Let's Encrypt certs via Cloudflare DNS-01 ACME
- The `caddy.tls.dns` label pattern is unchanged
- `tls internal` labels are phased out in favor of Smallstep-issued certs where applicable

### Smallstep CA (new)

Deploy `step-ca` as a Docker Swarm service for all internal certificate needs:

- **Primary use case:** Issue TLS certificates for Komodo Periphery (and any future service-to-service TLS)
- **Secondary use case:** ACME server for services that need Let's Encrypt-style automation but aren't proxied by Caddy
- **Root CA trust:** The Smallstep root certificate is distributed to consuming services via a mounted volume or Docker config
- **Certificate lifecycle:** Automated issuance and renewal via the ACME protocol (step-ca has a built-in ACME provisioner)

### Periphery migration path

1. Deploy step-ca with an ACME provisioner on the `proxy_network` overlay
2. Configure Periphery to obtain its TLS cert from step-ca instead of self-signing
3. Mount the step-ca root CA into Komodo Core's trust store
4. Remove `insecure_tls = true` from all server entries in `komodo/resources.toml`

## Consequences

### Positive

- **Verified TLS everywhere** — no more `insecure_tls = true`; MITM attacks on the management plane are prevented
- **Clean separation of concerns** — Caddy handles browser-facing ACME, Smallstep handles internal PKI
- **Automated renewal** — step-ca's ACME provisioner means no manual cert rotation
- **Extensible** — any future internal service can request a cert from step-ca without modifying Caddy
- **Browser-friendly** — services accessed via browser keep real LE certs through Caddy

### Negative

- **New service to operate** — step-ca adds a container and its root key material to the infrastructure tier
- **Root CA key protection** — the step-ca root key must be stored securely (1Password or encrypted volume); compromise would allow impersonation of any internal service
- **Bootstrap dependency** — step-ca must start before Periphery can obtain its cert; adds to the infrastructure tier boot sequence

### Neutral

- Caddy's existing `tls internal` labels continue to work but are not the preferred path for new services
- The Smallstep root CA is only trusted by internal services — it has no effect on browser trust or public DNS
