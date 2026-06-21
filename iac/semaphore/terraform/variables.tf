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
  default = "pve"
}

variable "proxmox_ssh_user" {
  type = string
}

variable "proxmox_ssh_password" {
  type      = string
  sensitive = true
}

variable "template_name" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}
