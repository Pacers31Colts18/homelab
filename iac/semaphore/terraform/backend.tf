terraform {
  backend "local" {
    path = "/terraform-state/proxmox.tfstate"
  }
}
