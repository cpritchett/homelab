output "node_ip" {
  description = "IP address of the provisioned VM"
  value       = var.vm_ip
}

output "hostname" {
  description = "Hostname of the provisioned node"
  value       = var.hostname
}

output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.node.vm_id
}
