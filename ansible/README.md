# Ansible — Node Configuration & Hardening

Ansible manages everything after SSH is available on a swarm node: Docker, NFS, Komodo Periphery, and OS hardening. OpenTofu creates Proxmox VMs; bare metal nodes (lorcha, dhow) skip OpenTofu entirely and are targeted by Ansible directly after PXE/preseed.

## Architecture

```
                    ┌──────────────────────────────────────────────────┐
                    │                  Your Mac                        │
                    │                                                  │
                    │  ┌────────────┐         ┌───────────────────┐   │
                    │  │  OpenTofu  │         │     Ansible       │   │
                    │  │            │         │                   │   │
                    │  │ Creates    │         │ site.yml          │   │
                    │  │ Proxmox   │         │  ├─ common        │   │
                    │  │ VMs only  │         │  ├─ hardening     │   │
                    │  │            │         │  ├─ docker        │   │
                    │  └─────┬──────┘         │  ├─ nfs           │   │
                    │        │                │  └─ periphery     │   │
                    │        │                └────────┬──────────┘   │
                    └────────┼───────────────────────┼──────────────┘
                             │ creates VMs            │ SSH
                             ▼                        ▼
           ┌─────────────────────┐     ┌──────────────────────────┐
           │      Proxmox        │     │      All Swarm Nodes     │
           │  ching-pve (VMs)    │     │                          │
           │  angre-pve (VMs)    │     │  ching    (10.0.5.93)    │
           └─────────────────────┘     │  angre    (10.0.5.130)   │
                                       │  lorcha   (10.0.5.215)   │
                                       │  dhow     (10.0.5.220)   │
                                       └──────────────────────────┘
```

## Tool Boundary

| OpenTofu (infrastructure)      | Ansible (configuration)              |
|-------------------------------|--------------------------------------|
| Create Proxmox VMs            | Wait for SSH (`wait_for_connection`) |
| Output VM IPs (informational) | Install & configure Docker CE        |
|                               | Mount NFS shares                     |
|                               | Install Komodo Periphery             |
|                               | OS hardening (SSH, firewall, fail2ban)|
|                               | Ongoing drift remediation (re-run)   |

## Directory Structure

```
ansible/
├── ansible.cfg                          # Config (inventory path, pipelining, YAML output)
├── requirements.yml                     # Galaxy role + collection deps
├── inventory/
│   ├── hosts.yml                        # Static inventory (4 nodes, 2 groups)
│   ├── group_vars/
│   │   ├── all.yml                      # Shared vars (NFS, Docker, domain)
│   │   ├── managers.yml                 # Manager-specific vars
│   │   └── workers.yml                  # Worker-specific vars
│   └── host_vars/
│       ├── ching.yml                    # Per-node overrides
│       ├── angre.yml
│       ├── lorcha.yml
│       └── dhow.yml
├── playbooks/
│   ├── site.yml                         # Full bootstrap (all roles)
│   ├── hardening.yml                    # Hardening-only (re-run safe)
│   └── docker.yml                       # Docker-only
└── roles/
    ├── common/                          # Base OS: hostname, timezone, packages, media user
    ├── docker/                          # Docker CE via geerlingguy.docker + daemon.json
    ├── nfs/                             # NFS client, mount points, fstab
    ├── periphery/                       # Komodo Periphery binary, config, TLS, systemd
    └── hardening/                       # devsec.hardening + nftables + fail2ban
```

## Roles

### common
Base OS setup: sets hostname, timezone, installs base packages (`curl`, `jq`, `htop`, `qemu-guest-agent`), creates media user (UID 1701) and group (GID 1702), enables qemu-guest-agent.

### docker
Wraps `geerlingguy.docker` (v7.4.1) for Docker CE installation with Compose plugin. Deploys `daemon.json` from the `docker_daemon_options` variable (overlay2, json-file logging with rotation).

### nfs
Installs `nfs-common`, creates mount points, uses `ansible.posix.mount` for each entry in `nfs_mounts` (manages fstab + immediate mount).

### periphery
Downloads the Komodo Periphery binary (architecture-aware: x86_64/aarch64), deploys config from template with `komodo_passkey`, generates self-signed TLS cert, installs systemd unit.

### hardening
Wraps `devsec.hardening` (os + ssh hardening) with homelab-compatible overrides (IPv6 enabled for Docker Swarm, ip_forward=1). Deploys nftables firewall (allow SSH, Periphery 8120, Swarm ports 2377/7946/4789, ICMP; default deny inbound). Installs fail2ban for SSH brute-force protection.

## Quick Reference

```sh
# Install Galaxy dependencies (first time)
cd ansible
ansible-galaxy install -r requirements.yml

# Full bootstrap — all roles, all nodes
ansible-playbook playbooks/site.yml --extra-vars "komodo_passkey=..."

# Hardening only
ansible-playbook playbooks/hardening.yml

# Docker config only
ansible-playbook playbooks/docker.yml

# Single node
ansible-playbook playbooks/site.yml --limit ching --extra-vars "komodo_passkey=..."

# Dry run
ansible-playbook playbooks/site.yml --check --diff --extra-vars "komodo_passkey=..."

# Ping all nodes
ansible all -m ping
```

## Secrets

`komodo_passkey` is passed via `--extra-vars` at runtime (not committed). Source it from 1Password:

```sh
ansible-playbook playbooks/site.yml \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

For a more permanent solution, Ansible Vault can encrypt it in `group_vars/all.yml`.

## Runbooks

- [Node Bootstrap](../ops/runbooks/ansible-node-bootstrap.md) — Full bootstrap of new or rebuilt nodes
- [Hardening Operations](../ops/runbooks/ansible-hardening.md) — Re-hardening and security updates
- [Day-2 Operations](../ops/runbooks/ansible-day2-operations.md) — Drift remediation, config updates, troubleshooting

## Related

- `opentofu/` — Proxmox VM creation (infrastructure layer)
- `stacks/infrastructure/pxe/` — PXE boot and Matchbox preseed
- `komodo/resources.toml` — Komodo resource sync (picks up Periphery after Ansible)
- `docs/deployment/PHASE1_DEPLOYMENT_RUNBOOK.md` — TrueNAS infrastructure bootstrap
