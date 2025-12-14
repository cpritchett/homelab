# Glossary

- **Mgmt-Consoles**: A device group allowed to initiate traffic into the Management network.
- **Management network**: VLAN 100 / 10.0.100.0/24 containing critical infrastructure endpoints (BMC/IPMI/KVM/PDU/network gear).
- **Intent domain**: A DNS zone whose suffix encodes trust boundary and expected access path.
- **Tunnel-only ingress**: All external access traverses Cloudflare Tunnel and (typically) Cloudflare Access.
