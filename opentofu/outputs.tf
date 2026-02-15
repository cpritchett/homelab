output "vm_ips" {
  description = "IP addresses of Proxmox VMs (informational — Ansible inventory is static)"
  value = {
    ching = module.ching.node_ip
    angre = module.angre.node_ip
  }
}
