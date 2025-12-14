# Risk Register

| ID | Risk | Impact | Mitigation | Owner | Status |
|----|------|--------|------------|-------|--------|
| R-001 | Accidental public exposure | High | Tunnel-only ingress; no port forwards; Access policies | TBD | Open |
| R-002 | Mgmt network compromise | Critical | VLAN isolation; allowlist via Mgmt-Consoles; no default egress | TBD | Open |
| R-003 | DNS ambiguity / bypass | High | Separate intent domains; no split-horizon override of public names | TBD | Open |
| R-004 | Automation churn overload | Medium | Split controllers; scoped domains; rate limits | TBD | Open |
| R-005 | Operator lockout | Medium | Mgmt-Consoles as sole bridge; overlay allowed only on consoles | TBD | Open |
