# Management Network Requirements
**Effective:** 2025-12-14

## Definition

The Management network contains critical infrastructure:
- BMC/IPMI/iDRAC/iLO
- KVMs
- PDUs
- Network devices
- Other OOB endpoints

## Network identity

| Property | Value |
|----------|-------|
| VLAN | 100 |
| CIDR | `10.0.100.0/24` |

## Access invariants

1. **Only devices in Mgmt-Consoles may initiate traffic into the Management network**
   - No other device class may originate connections

2. **Management has no Internet egress by default**
   - Egress may be allowed only via explicit allow rules
   - Exceptions must be documented in an ADR or runbook entry

3. **Management is sacred and boring**
   - Isolated, predictable, minimally reachable

## Rationale

Management network contains the most sensitive infrastructure. Compromise of these systems allows complete loss of control.

See: [ADR-0003](../../docs/adr/ADR-0003-management-network.md)
