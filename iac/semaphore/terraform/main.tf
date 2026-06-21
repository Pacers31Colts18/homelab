data "proxmox_virtual_environment_vms" "template" {
  node_name = var.proxmox_node

  filter {
    name   = "name"
    values = [var.template_name]
  }
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data      = <<-EOF
    #cloud-config
    hostname: ${var.vm_name}
    manage_etc_hosts: true
    EOF
    file_name = "${var.vm_name}-cloud-config.yaml"
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

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    meta_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  started = true
}
