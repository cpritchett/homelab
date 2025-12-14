# Hard-Stop Conditions
**Effective:** 2025-12-14

Agents must **stop and ask** before proceeding if a proposed change would:

1. **Expose services directly to WAN** (any port forward / WAN listener)
2. **Publish `in.hypyr.space` publicly** (internal zone must remain internal-only)
3. **Allow non-console access to Management** (only Mgmt-Consoles may initiate traffic into Management)
4. **Install overlay agents on Management VLAN devices** (overlay is for trusted human endpoints, not management infrastructure)
5. **Override a public FQDN internally to bypass Cloudflare Access** (no split-horizon to circumvent identity gating)

## Rationale

These conditions represent violations of constitutional principles that could expose critical infrastructure or bypass security boundaries. Human review is required before any action that would trigger these conditions.

See: [constitution/constitution.md](../constitution/constitution.md)
