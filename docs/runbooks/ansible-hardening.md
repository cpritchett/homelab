# Runbook: Ansible Hardening Operations

**Scope:** OS and SSH hardening for Docker Swarm nodes via Ansible.

**When to use:**
- After a devsec.hardening collection update
- When a new CIS benchmark is published
- When SSH or firewall policy changes are needed
- Periodic re-hardening to remediate configuration drift

## What the Hardening Role Does

```
hardening role
├── devsec.hardening.os_hardening    → sysctl, kernel modules, file permissions
├── devsec.hardening.ssh_hardening   → sshd_config (key-only, no root, deploy user only)
├── nftables firewall                → default deny inbound, allow:
│   │                                    SSH (22), Periphery (8120),
│   │                                    Swarm (2377, 7946 TCP+UDP, 4789 UDP),
│   │                                    ICMP
│   └── forward chain                → policy accept (Docker manages)
└── fail2ban                         → SSH brute-force protection (5 retries, 1h ban)
```

## Homelab-Specific Overrides

These deviate from devsec defaults for Docker Swarm compatibility:

| Setting | devsec Default | Homelab Override | Reason |
|---------|---------------|-----------------|--------|
| `os_hardening_ipv6_disable` | `true` | `false` | Docker Swarm uses IPv6 internally |
| `net.ipv4.ip_forward` | `0` | `1` | Required for Docker routing |
| `net.bridge.bridge-nf-call-iptables` | `0` | `1` | Required for Docker networking |
| `os_auth_pw_max_age` | `60` | `99999` | Key-only auth, no password expiry |

## Running Hardening

**All nodes:**

```bash
cd ansible
ansible-playbook playbooks/hardening.yml
```

**Single node:**

```bash
ansible-playbook playbooks/hardening.yml --limit ching
```

**Dry run (check what would change):**

```bash
ansible-playbook playbooks/hardening.yml --check --diff
```

## Verification

### SSH Hardening

```bash
# Verify password auth is disabled
ansible swarm_nodes -a "sshd -T" --become | grep -E 'passwordauthentication|permitrootlogin|maxauthtries'
```

**Expected:**
```
passwordauthentication no
permitrootlogin no
maxauthtries 3
```

### Firewall (nftables)

```bash
# List active ruleset
ansible swarm_nodes -a "nft list ruleset" --become
```

**Expected:** Input chain with policy drop, rules allowing SSH/8120/Swarm ports/ICMP.

```bash
# Verify specific ports are open
ansible swarm_nodes -a "ss -tlnp" --become | grep -E '22|8120|2377|7946'
```

### Fail2ban

```bash
# Check fail2ban status
ansible swarm_nodes -a "fail2ban-client status sshd" --become
```

**Expected:** Jail `sshd` active with 0 currently banned (unless under attack).

### Sysctl

```bash
# Verify Docker-critical sysctl settings
ansible swarm_nodes -a "sysctl net.ipv4.ip_forward" --become
ansible swarm_nodes -a "sysctl net.bridge.bridge-nf-call-iptables" --become
```

**Expected:** Both return `= 1`.

## Updating devsec.hardening

When a new version of `devsec.hardening` is released:

```bash
# Update Galaxy collection
ansible-galaxy collection install devsec.hardening --force

# Dry run to see what changes
ansible-playbook playbooks/hardening.yml --check --diff

# Review changes carefully, then apply
ansible-playbook playbooks/hardening.yml
```

Review the [devsec.hardening changelog](https://github.com/dev-sec/ansible-collection-hardening/releases) for breaking changes before upgrading.

## Emergency: Locked Out of SSH

If hardening misconfiguration locks you out:

1. **Proxmox VMs (ching, angre):** Access via Proxmox console (noVNC/SPICE)
2. **Bare metal (lorcha, dhow):** Physical console or IPMI/iDRAC

Once on the console:
```bash
# Temporarily allow password auth
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Fix the issue, then re-run hardening
```

## Related

- [ansible/README.md](../../ansible/README.md) — Ansible directory overview
- [Node Bootstrap](ansible-node-bootstrap.md) — Full bootstrap runbook
- [Day-2 Operations](ansible-day2-operations.md) — Drift remediation and config updates
- `ansible/roles/hardening/defaults/main.yml` — Hardening variable overrides
