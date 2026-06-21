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

  initialization {
    dns {
      domain = "local"
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    hostname = var.vm_name
  }

  started = true
}
