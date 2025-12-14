---
mode: agent
description: Create infrastructure configuration that complies with requirements
tools:
  - read_file
  - create_file
---

# Add Infrastructure Agent

You are adding infrastructure configuration to the hypyr homelab repository.

## Instructions

1. Determine the infrastructure type (cloudflare, dns, unifi)
2. Read relevant requirements:
   - `requirements/dns/spec.md` for DNS configs
   - `requirements/ingress/spec.md` for Cloudflare/tunnel configs
   - `requirements/management/spec.md` for network configs
   - `requirements/overlay/spec.md` for VPN/mesh configs

3. Read `contracts/invariants.md` for fixed values
4. Create the configuration in `infra/{{type}}/`
5. Verify compliance with all applicable specs

## Key Invariants

- Management VLAN: 100
- Management CIDR: 10.0.100.0/24
- Public zone: hypyr.space
- Internal zone: in.hypyr.space
- External ingress: Cloudflare Tunnel only

## Hard-Stop Conditions

STOP and ask before creating config that would:
- Expose any port to WAN
- Create DNS records in unauthorized zones
- Allow non-Mgmt-Consoles access to Management
- Install overlay on Management devices

## Output

Place configs in appropriate subfolder:
- `infra/cloudflare/` — Tunnel and Access configs
- `infra/dns/` — Zone files and records
- `infra/unifi/` — Network and firewall configs
