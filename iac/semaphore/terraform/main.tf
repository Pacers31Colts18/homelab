data "proxmox_virtual_environment_vms" "template" {
  node_name = var.proxmox_node

  filter {
    name   = "name"
    values = [var.template_name]
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.proxmox_node

  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  initialization {
    dns {
      domain  = "local"
      servers = []
    }

    hostname = var.vm_name

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  started = true
}
