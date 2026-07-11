variable "proxmox_api_host" {
  type = string
}

variable "proxmox_api_user" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "pve00"
}


variable "template_vm_id" {
  type    = number
  default = 998
}

variable "vm_name" {
  type = string
}

variable "cpu_cores" {
  type    = number
  default = 1
}

variable "memory" {
  type    = number
  default = 2048
}
