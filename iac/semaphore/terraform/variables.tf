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

variable "template_name" {
  type = string
}

variable "vm_name" {
  type = string
}
