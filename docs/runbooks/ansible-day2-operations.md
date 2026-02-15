# Runbook: Ansible Day-2 Operations

**Scope:** Ongoing configuration management, drift remediation, and troubleshooting for Docker Swarm nodes.

**When to use:**
- Periodic drift checks (re-converge all nodes)
- Docker daemon configuration changes
- NFS mount changes
- Periphery updates
- Investigating node issues

## Workflow Diagram

```
                         ┌─────────────────────────────┐
                         │     Day-2 Operations         │
                         └─────────────┬───────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
              ▼                        ▼                        ▼
     ┌────────────────┐    ┌───────────────────┐    ┌──────────────────┐
     │  Full re-run   │    │  Targeted playbook │    │  Ad-hoc command  │
     │  site.yml      │    │  docker.yml        │    │  ansible <host>  │
     │  (all roles)   │    │  hardening.yml     │    │    -m <module>   │
     └────────────────┘    └───────────────────┘    └──────────────────┘
              │                        │                        │
              ▼                        ▼                        ▼
     0 changed = no drift    targeted fix applied     quick investigation
```

## Full Re-convergence (Drift Remediation)

Re-run the full playbook periodically to ensure all nodes match desired state:

```bash
cd ansible

ansible-playbook playbooks/site.yml \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

**Expected on a healthy cluster:** `0 changed` across all tasks. Any changes indicate drift that was automatically corrected.

## Common Day-2 Tasks

### Update Docker Daemon Configuration

1. Edit `ansible/inventory/group_vars/all.yml` — modify `docker_daemon_options`
2. Apply:

```bash
ansible-playbook playbooks/docker.yml
```

This deploys the updated `daemon.json` and restarts Docker on all nodes.

### Update NFS Mounts

1. Edit `ansible/inventory/group_vars/all.yml` — modify `nfs_mounts`
2. Apply:

```bash
ansible-playbook playbooks/site.yml \
  --tags nfs \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

Or run the full playbook (NFS role is idempotent).

### Update Periphery

To update the Periphery binary on all nodes:

```bash
# Remove the old binary so Ansible re-downloads
ansible swarm_nodes -a "rm /usr/local/bin/periphery" --become

# Re-run site.yml (periphery role will download latest)
ansible-playbook playbooks/site.yml \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

### Add a New Node

1. Add the node to `ansible/inventory/hosts.yml` under the appropriate group
2. Create a host_vars file if needed: `ansible/inventory/host_vars/<hostname>.yml`
3. Run the full bootstrap:

```bash
ansible-playbook playbooks/site.yml \
  --limit <hostname> \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

4. Add the node to `komodo/resources.toml` for Komodo management

### Remove a Node

1. Drain the node from the swarm (via Komodo or `docker node update --availability drain`)
2. Remove from `ansible/inventory/hosts.yml`
3. Remove from `komodo/resources.toml`
4. [Proxmox VMs] Remove from `opentofu/main.tf` and run `tofu apply`

## Ad-Hoc Investigation Commands

```bash
# Check disk space on all nodes
ansible swarm_nodes -a "df -h /"

# Check Docker service status
ansible swarm_nodes -a "systemctl is-active docker"

# Check memory usage
ansible swarm_nodes -a "free -h"

# Check uptime
ansible swarm_nodes -a "uptime"

# List running containers
ansible swarm_nodes -a "docker ps --format 'table {{.Names}}\t{{.Status}}'" --become

# Check Periphery logs
ansible swarm_nodes -a "journalctl -u periphery --no-pager -n 20" --become

# Check fail2ban status
ansible swarm_nodes -a "fail2ban-client status sshd" --become

# Check NFS mount health
ansible swarm_nodes -a "mountpoint /mnt/apps01/appdata && echo OK || echo FAILED"
```

## Troubleshooting

### Node Not Responding to Ansible

```bash
# Test basic connectivity
ansible <hostname> -m ping

# Test with verbose output
ansible <hostname> -m ping -vvv

# Try raw SSH
ssh deploy@<ip>
```

Common causes:
- Node is down or rebooting
- SSH key not authorized (check preseed)
- Firewall blocking SSH (access via console, check nftables)

### Docker Service Won't Start

```bash
ansible <hostname> -a "journalctl -u docker --no-pager -n 50" --become
ansible <hostname> -a "cat /etc/docker/daemon.json" --become
```

Common causes:
- Invalid `daemon.json` (re-run docker playbook)
- Disk full (check `df -h`)

### NFS Mount Stale

```bash
# Check mount status
ansible <hostname> -a "mountpoint /mnt/apps01/appdata"

# Force remount
ansible <hostname> -a "umount -l /mnt/apps01/appdata && mount /mnt/apps01/appdata" --become

# Or re-run NFS role
ansible-playbook playbooks/site.yml --limit <hostname> \
  --extra-vars "komodo_passkey=$(op read 'op://homelab/Komodo - Barbary/credential')"
```

### Periphery Not Connecting to Komodo

```bash
# Check Periphery is running
ansible <hostname> -a "systemctl status periphery" --become

# Check Periphery logs for passkey mismatch
ansible <hostname> -a "journalctl -u periphery --no-pager -n 30" --become

# Verify port is listening
ansible <hostname> -a "ss -tlnp sport = :8120"

# Test TLS cert validity
ansible <hostname> -a "openssl x509 -in /etc/komodo/ssl/cert.pem -noout -dates"
```

## Related

- [ansible/README.md](../../ansible/README.md) — Ansible directory overview
- [Node Bootstrap](ansible-node-bootstrap.md) — Full bootstrap runbook
- [Hardening Operations](ansible-hardening.md) — Re-hardening runbook
- [NAS Stacks Deployment](stacks-deployment.md) — Komodo stack deployment
