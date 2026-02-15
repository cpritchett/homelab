# Two independent Proxmox instances — one per physical host.
# These are the *-pve hypervisor IPs, not the VM IPs.
# Each PVE host runs a single Debian VM (swarm manager).

provider "proxmox" {
  alias    = "ching"
  endpoint = "https://10.0.5.92:8006"
  api_token = var.proxmox_ching_token
  insecure  = true

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "angre"
  endpoint = "https://10.0.5.129:8006"
  api_token = var.proxmox_angre_token
  insecure  = true

  ssh {
    agent = true
  }
}
