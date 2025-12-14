# Invariants
**Effective:** 2025-12-14

These conditions must **always be true**. Any change that would violate an invariant is invalid.

## Network Identity Invariants

| Resource | Value | Notes |
|----------|-------|-------|
| Management VLAN | 100 | Fixed |
| Management CIDR | `10.0.100.0/24` | Fixed |
| Public zone | `hypyr.space` | Cloudflare-managed |
| Internal zone | `in.hypyr.space` | Local DNS only |

## Access Invariants

1. **Management network has no Internet egress by default**
   - Egress may be allowed only via explicit allow rules documented in an ADR

2. **Only Mgmt-Consoles may initiate traffic into Management**
   - No other device class may originate connections to Management VLAN

3. **External ingress is Cloudflare Tunnel only**
   - No port forwards
   - No WAN-exposed listeners
   - No "temporary" openings without documented exception

4. **Overlay agents are prohibited on Management VLAN devices**
   - Overlay is transport for trusted humans, not management infrastructure

## DNS Invariants

1. **No additional internal suffixes** (`.lan`, `.local`, `.home` are prohibited)

2. **No split-horizon overrides** (public FQDN must not resolve to internal target)

3. **Zone dependency boundaries**:
   - Internal-only services MUST NOT depend on `hypyr.space` resolution
   - Public services MUST NOT depend on `in.hypyr.space` resolution
