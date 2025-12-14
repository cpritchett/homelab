# DNS Intent Requirements
**Effective:** 2025-12-14

## Authoritative zones

| Zone | Type | Authority |
|------|------|-----------|
| `hypyr.space` | Public | Cloudflare-managed |
| `in.hypyr.space` | Internal | Local DNS only |

## Naming rules

- Public services MUST use: `<service>.hypyr.space`
- Internal-only services MUST use: `<service>.in.hypyr.space`

## Prohibitions

1. Agents MUST NOT introduce additional "internal suffixes" (e.g. `.lan`, `.local`, `.home`)

2. Agents MUST NOT implement split-horizon overrides that make a public name resolve to an internal target (no "same FQDN, different answers" to bypass Access)

3. Internal-only services MUST NOT depend on `hypyr.space` resolution

4. Public services MUST NOT depend on `in.hypyr.space` resolution

## Rationale

DNS encodes intent and trust boundaries. Mixing zones or adding alternative suffixes creates ambiguity that undermines structural safety.

See: [ADR-0001](../../docs/adr/ADR-0001-dns-intent.md)
