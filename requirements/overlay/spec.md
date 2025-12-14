# Overlay Networking Requirements
**Effective:** 2025-12-14

## Scope

Overlay networking refers to Tailscale, Headscale, or similar mesh VPN solutions.

## Placement rules

| Allowed | Prohibited |
|---------|------------|
| Mgmt-Consoles endpoints (laptops/workstations) | Management VLAN devices |
| Admin VM not on the Management VLAN | Any device in 10.0.100.0/24 |

## Purpose

Overlay is a transport for trusted humans, not an ingress mechanism for management infrastructure.

## Prohibition

Overlay agents MUST NOT run on Management VLAN devices.

## Rationale

Installing overlay agents on management devices would create an alternative path into critical infrastructure that bypasses the Mgmt-Consoles access model.
