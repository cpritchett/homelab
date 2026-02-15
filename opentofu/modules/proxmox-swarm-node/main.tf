terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.69"
    }
  }
}

# ── Proxmox VM ────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "node" {
  name      = var.hostname
  node_name = "pve"
  vm_id     = var.vm_id

  description = "Docker Swarm node — managed by OpenTofu"
  tags        = ["swarm", "opentofu"]

  bios       = "seabios"
  machine    = "q35"
  on_boot    = true
  started    = true

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.ram_mb
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = var.disk_gb
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = var.vm_mac
    model       = "virtio"
  }

  boot_order = ["net0", "scsi0"]

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  lifecycle {
    ignore_changes = [boot_order]
  }
}

# Post-install configuration (Docker, NFS, Periphery, hardening) is
# handled by Ansible. Run: ansible-playbook playbooks/site.yml
