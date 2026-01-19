# ADR-0024: Authentik Authentication Stack for NAS Services

**Status:** Accepted  
**Date:** 2025-01-17  
**Deciders:** System Architecture  

## Context

The homelab NAS deployment system (TrueNAS + Docker Compose stacks) currently lacks centralized authentication. Services are either unprotected or rely on individual authentication mechanisms, creating security gaps and operational overhead.

Key requirements:
- Centralized authentication for all NAS-hosted services
- Forward authentication pattern compatible with Caddy reverse proxy
- Fail-safe design: services must boot without requiring auth to be available
- Emergency bypass capability for operational recovery
- No external dependencies beyond existing infrastructure

## Decision

Implement Authentik as the centralized authentication provider for NAS services using forward authentication pattern.

### Architecture Components

1. **Authentik Stack** (`stacks/authentik/`)
   - PostgreSQL database for user/session data
   - Redis cache for session management
   - Authentik server (web UI + API)
   - Authentik worker (background tasks)

2. **Stack Ordering**
   ```
   proxy (order=10) → authentik (order=20) → protected services (order=30+)
   ```

3. **Forward Auth Integration**
   - Caddy forward_auth directive routes auth requests to Authentik
   - Auth headers passed to backend services
   - Health endpoints bypass authentication

### Failure Modes & Mitigations

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Authentik down | New auth fails | Health endpoints remain accessible |
| Database failure | Auth unavailable | Emergency bypass script available |
| Network issues | Auth timeouts | Short timeouts, fail-open for critical paths |
| Bootstrap chicken-egg | Can't access admin UI | Bootstrap credentials in environment |

## Implementation Details

### Stack Dependencies
```toml
[stacks.authentik]
depends_on = ["proxy"]
order = 20

[stacks.protected-service]
depends_on = ["authentik"]
order = 30+
```

### Forward Auth Labels Pattern
```yaml
labels:
  caddy: "service.in.hypyr.space"
  caddy.reverse_proxy: "http://service:8080"
  caddy.forward_auth: "http://authentik-server:9000/outpost.goauthentik.io/auth/caddy"
  caddy.forward_auth.uri: "/outpost.goauthentik.io/auth/caddy"
  caddy.forward_auth.copy_headers: "X-authentik-username X-authentik-groups X-authentik-email"
  caddy.handle_path: "/health"
  caddy.handle_path.respond: "ok 200"
```

### Emergency Recovery
- `emergency-bypass.sh` script disables auth for all services
- Health endpoints always accessible without authentication
- Bootstrap credentials allow initial admin access

## Consequences

### Positive
- Centralized user management and authentication
- Consistent security posture across all services
- SSO experience for users
- Audit trail for access events
- Forward auth headers enable service-level authorization

### Negative
- Additional infrastructure complexity
- Single point of failure for authentication
- Bootstrap dependency: Authentik must be healthy for protected services
- Operational overhead for user/group management

### Neutral
- Services must implement health endpoints for monitoring
- Emergency procedures required for auth bypass scenarios
- 1Password integration required for secret management

## Compliance

### Constitutional Principles
- ✅ **Management is Sacred**: Auth system runs on trusted network only
- ✅ **DNS Encodes Intent**: Internal auth at `auth.in.hypyr.space`
- ✅ **External Access Identity-Gated**: Public auth via Cloudflare Tunnel
- ✅ **Structural Safety**: Emergency bypass prevents lockout scenarios

### Invariants
- ✅ **No WAN Exposure**: Auth endpoints only via Cloudflare Tunnel
- ✅ **Internal Zone Isolation**: `in.hypyr.space` remains internal-only
- ✅ **Stack Registry**: All stacks registered with proper dependencies

## References

- [Constitution](../../constitution/constitution.md) - Immutable principles
- [Hard Stops](../../contracts/hard-stops.md) - Actions requiring approval
- [Stack Registry](../../contracts/invariants.md#repository-structure-invariants) - Deployment ordering requirements
- [ADR-0021](./ADR-0021-stacks-registry-required.md) - Stack registry requirement
- [ADR-0022](./ADR-0022-explicit-stack-ordering.md) - Stack ordering system