# ADR-0039: TLS Verification Policy

**Status:** Accepted
**Date:** 2026-02-24
**Relates to:** ADR-0038 (Internal PKI with Smallstep CA)

## Context

With the adoption of Smallstep CA (ADR-0038), the homelab now has a complete
internal PKI. Every internal service can obtain a trusted certificate, and
every client can verify it by trusting the Smallstep root CA.

Despite this, `ignoreTls`, `insecure_tls`, and equivalent TLS bypass flags
have appeared in monitoring configurations and service connections out of
convenience — even on the CA's own health monitor. This undermines the entire
purpose of running a PKI: if verification is skipped, a compromised or
impersonating service would go undetected.

The correct fix is always to distribute the root CA certificate to the
verifying service, not to disable verification.

## Decision

**All TLS connections within the homelab MUST verify certificates.** TLS
bypass flags (`ignoreTls`, `insecure_tls`, `--insecure`, `NODE_TLS_REJECT_UNAUTHORIZED=0`,
etc.) are prohibited without a documented exception via ADR.

### Trust distribution

Services that need to verify internal (Smallstep) certificates MUST trust
the root CA through the appropriate mechanism for their runtime:

| Runtime | Trust Mechanism | Example |
|---------|----------------|---------|
| Node.js | `NODE_EXTRA_CA_CERTS` env var | Uptime Kuma, Seerr |
| Go | System trust store or `SSL_CERT_FILE` | Komodo Periphery |
| Python | `REQUESTS_CA_BUNDLE` or `SSL_CERT_FILE` | Apprise |
| Java | JVM truststore (`keytool -import`) | — |
| curl/wget | `--cacert` flag or system trust store | Healthchecks |

The Smallstep root CA is available at:
`/mnt/apps01/appdata/step-ca/certs/root_ca.crt`

Services mount it read-only and configure their runtime to trust it.

### Exceptions

A TLS bypass is permitted **only** when:

1. The service has no mechanism to add custom CA certificates (verified, not assumed)
2. An ADR documents the limitation, the risk, and the mitigation
3. The bypass is scoped to the specific connection, not global

No blanket `NODE_TLS_REJECT_UNAUTHORIZED=0` or equivalent global disables.

## Consequences

### Positive

- **Real security** — TLS verification catches certificate expiry, misconfigurations, and MITM attempts
- **PKI investment pays off** — deploying Smallstep CA without enforcing verification is security theater
- **Fail-visible** — a misconfigured trust store causes an immediate, obvious failure rather than silent bypass

### Negative

- **More work per service** — each service consuming internal TLS needs its trust store configured
- **Startup dependency** — services must have the root CA available before making TLS connections

### Neutral

- Browser-facing services behind Caddy are unaffected (they use Let's Encrypt certs)
- This policy applies to service-to-service and monitoring connections only

## References

- ADR-0038: [Internal PKI with Smallstep CA](ADR-0038-internal-pki-smallstep.md)
- Invariants: [contracts/invariants.md](../../contracts/invariants.md) — TLS/PKI Invariants section
- Hard-Stops: [contracts/hard-stops.md](../../contracts/hard-stops.md) — item 6
