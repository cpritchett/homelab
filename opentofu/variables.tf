# ── Proxmox API Tokens ────────────────────────────────────

variable "proxmox_ching_token" {
  description = "Proxmox API token for ching-pve (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_angre_token" {
  description = "Proxmox API token for angre-pve (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

# ── Proxmox VM MAC Addresses ─────────────────────────────
# VMs are PXE-booted and matched by MAC in Matchbox groups.

variable "ching_vm_mac" {
  description = "MAC address for ching VM NIC (must match Matchbox group)"
  type        = string
  default     = "BC:24:11:00:05:93"
}

variable "angre_vm_mac" {
  description = "MAC address for angre VM NIC (must match Matchbox group)"
  type        = string
  default     = "BC:24:11:00:05:30"
}
