variable "hostname" {
  description = "VM hostname"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
}

variable "vm_ip" {
  description = "Expected IP address of the VM after Debian install"
  type        = string
}

variable "vm_mac" {
  description = "MAC address for VM NIC (must match Matchbox group)"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "ram_mb" {
  description = "RAM in MB"
  type        = number
}

variable "disk_gb" {
  description = "Disk size in GB"
  type        = number
}
