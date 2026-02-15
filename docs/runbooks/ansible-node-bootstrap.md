# Runbook: Ansible Node Bootstrap

**Scope:** Full bootstrap of new or rebuilt Docker Swarm nodes via Ansible.

**When to use:** After a node completes PXE/preseed (Debian installed, SSH available) — either a new Proxmox VM created by OpenTofu or a bare metal node after PXE boot.

## Prerequisites

- Ansible installed on your Mac (`brew install ansible`)
- Galaxy dependencies installed: `cd ansible && ansible-galaxy install -r requirements.yml`
- SSH access to the target node as `deploy` user (key-based, configured by preseed)
- `komodo_passkey` available (from 1Password: `op://homelab/Komodo - Barbary/credential`)
- `NFS_SERVER_IP` environment variable set (barbary's IP on 10.0.5.0/24)

## Workflow

```
PXE boot → Matchbox → Debian preseed (minimal OS + SSH)
    │
    │  [Proxmox VMs only]
    ├── tofu apply  (creates VM, triggers PXE boot)
    │
    ▼
ansible-playbook playbooks/site.yml --extra-vars "komodo_passkey=..."
    │
    ├── common      → hostname, timezone, base packages, media user
    ├── hardening   → devsec OS/SSH hardening, nftables, fail2ban
    ├── docker      → Docker CE + daemon.json
    ├── nfs         → nfs-common, fstab mounts
    └── periphery   → Periphery binary, config, TLS, systemd
    │
    ▼
Komodo picks up Periphery → swarm expansion via resources.toml
```

## Step 1: Verify SSH Connectivity

```bash
cd ansible
ansible all -m ping
```

**Expected:** All 4 nodes respond with `pong`. If bootstrapping a single new node:

```bash
ansible ching -m ping
```

If SSH fails, verify:
- Node has finished preseed installation (can take 10-20 minutes for PXE boot)
- SSH key is in preseed authorized_keys
- Network connectivity from your Mac to the 10.0.5.0/24 subnet

## Step 2: Run Full Bootstrap

**All nodes:**

```bash
export NFS_SERVER_IP=10.0.5.XXX  # Set to barbary's IP

ansible-playbook playbooks/site.yml \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

**Single node (e.g., after rebuilding ching):**

```bash
ansible-playbook playbooks/site.yml \
  --limit ching \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

**Dry run first (recommended for new nodes):**

```bash
ansible-playbook playbooks/site.yml \
  --check --diff \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

## Step 3: Verify Bootstrap

Run these checks on the target node(s):

```bash
# Docker installed and running
ansible swarm_nodes -a "docker --version"
ansible swarm_nodes -a "systemctl is-active docker"

# Periphery running
ansible swarm_nodes -a "systemctl is-active periphery"
ansible swarm_nodes -a "ss -tlnp sport = :8120"

# NFS mounts
ansible swarm_nodes -a "mountpoint /mnt/apps01/appdata"
ansible swarm_nodes -a "mountpoint /mnt/data01/data"

# Firewall
ansible swarm_nodes -a "nft list ruleset"

# SSH hardening
ansible swarm_nodes -a "sshd -T" | grep passwordauthentication
```

**Expected:**
- Docker version string returned
- `periphery` service active
- Port 8120 listening
- Both NFS mount points mounted
- nftables rules applied (SSH, 8120, Swarm ports allowed; default deny)
- `passwordauthentication no`

## Step 4: Verify Komodo Pickup

After Periphery is running, Komodo should detect the node:

1. Open Komodo UI: https://komodo.in.hypyr.space
2. Navigate to Servers — the new node should appear
3. If not, trigger a ResourceSync in Komodo to pull `komodo/resources.toml`

## Troubleshooting

### Ansible cannot reach node

```bash
# Test raw SSH
ssh deploy@10.0.5.93

# Check if preseed is still running (PXE boot can take 10-20 min)
# Look for the node in Proxmox UI or check DHCP leases on UniFi
```

### Docker install fails

```bash
# Check apt sources
ansible ching -a "cat /etc/apt/sources.list"

# Check if Docker GPG key was added
ansible ching -a "apt-key list" --become
```

### NFS mount fails

```bash
# Verify NFS server is reachable
ansible ching -a "showmount -e 10.0.5.XXX"

# Check if nfs-common is installed
ansible ching -a "dpkg -l nfs-common"
```

### Periphery not starting

```bash
# Check logs
ansible ching -a "journalctl -u periphery --no-pager -n 50" --become

# Verify binary exists and is executable
ansible ching -a "ls -la /usr/local/bin/periphery"

# Verify config
ansible ching -a "cat /etc/komodo/periphery.config.toml" --become

# Verify TLS cert
ansible ching -a "openssl x509 -in /etc/komodo/ssl/cert.pem -noout -subject -dates"
```

## Re-running (Idempotent)

The entire playbook is idempotent. Re-running on an already-bootstrapped node should produce `0 changed`:

```bash
ansible-playbook playbooks/site.yml \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

If changes are detected on re-run, investigate what drifted.

## Related

- [ansible/README.md](../../ansible/README.md) — Ansible directory overview
- [Hardening Operations](ansible-hardening.md) — Re-hardening runbook
- [Day-2 Operations](ansible-day2-operations.md) — Drift remediation and config updates
- [Phase 1 Deployment Runbook](../../docs/deployment/PHASE1_DEPLOYMENT_RUNBOOK.md) — TrueNAS infrastructure bootstrap
