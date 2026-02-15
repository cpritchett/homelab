# ── Proxmox VM Nodes (Managers) ───────────────────────────
# Cannot use for_each — different provider aliases per instance.
# Proxmox hosts (*-pve) and VMs have separate IPs.
# Swarm joining is handled by Komodo after Periphery is up.
# Post-install config (Docker, NFS, Periphery, hardening) is handled by Ansible.

module "ching" {
  source    = "./modules/proxmox-swarm-node"
  providers = { proxmox = proxmox.ching }

  hostname = "ching"
  vm_id    = 100
  vm_ip    = "10.0.5.93"
  vm_mac   = var.ching_vm_mac
  cores    = 16
  ram_mb   = 122880
  disk_gb  = 500
}

module "angre" {
  source    = "./modules/proxmox-swarm-node"
  providers = { proxmox = proxmox.angre }

  hostname = "angre"
  vm_id    = 100
  vm_ip    = "10.0.5.130"
  vm_mac   = var.angre_vm_mac
  cores    = 8
  ram_mb   = 57344
  disk_gb  = 256
}

# Bare metal nodes (lorcha, dhow) skip OpenTofu entirely.
# Ansible targets them directly after PXE/preseed completes.
