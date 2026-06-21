# Semaphore Infrastructure Automation

This guide covers provisioning VMs in Proxmox using Terraform via Semaphore, and configuring them with Ansible playbooks.

## Prerequisites

- Proxmox server with API access
- Semaphore running in Docker on a VM
- SSH key pair (`id_semaphore`) for automation
- A Proxmox VM template (see [template setup](../../proxmox/templates/readme.md))

## Architecture

```
Semaphore (Docker) --> Terraform --> Proxmox API --> Clone VM from template
                   --> Ansible  --> SSH into VM  --> Configure hostname, updates, etc.
```

---

## 1. Proxmox Setup

### API Token

Create a dedicated user and API token:

```bash
pveum user add terraform@pve
pveum role add TerraformRole -privs "Datastore.Allocate Datastore.AllocateSpace Pool.Audit SDN.Use Sys.Audit VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.GuestAgent.Audit VM.PowerMgmt"
pveum user token add terraform@pve terraform-token
```

Save the token secret.

Assign permissions:

```bash
pveum aclmod / -user terraform@pve -role TerraformRole
pveum aclmod / -token 'terraform@pve!terraform-token' -role TerraformRole
pveum aclmod /storage/local -token 'terraform@pve!terraform-token' -role TerraformRole
pveum aclmod /sdn/zones/localnetwork -token 'terraform@pve!terraform-token' -role TerraformRole
```

### SSH Access for Terraform Provider

The bpg/proxmox Terraform provider uses SSH to upload cloud-init snippets. Add the semaphore public key to the Proxmox host:

```bash
cat /path/to/id_semaphore.pub >> /root/.ssh/authorized_keys
```

### VM Template

Ensure your template (VM 999) has:

- `--cpu host` (required for amd64v3 cloud images)
- `--vga std` (not serial -- serial causes kernel panics on some images)
- `--ciuser` and `--cipassword` set for console login
- Cloud-init snippet attached for the semaphore automation user

See [proxmox/templates/readme.md](../../proxmox/templates/readme.md) for full template creation steps.

**Important corrections from the template readme:**
- Set `--cpu host` to support amd64v3 images
- Set `--ciuser jloveless123 --cipassword <password>` for console access
- Use `--cicustom "user=local:snippets/semaphore-user.yml"` (not `vendor=`) for the cloud-init snippet to be applied correctly

---

## 2. Semaphore Docker Setup

### docker-compose.yml

```yaml
services:
  semaphore:
    image: semaphoreui/semaphore:latest
    ports:
      - "3000:3000"
    env_file:
      - .env
    environment:
      SEMAPHORE_DB_DIALECT: sqlite
      SEMAPHORE_DB: /etc/semaphore/semaphore.sqlite
      SEMAPHORE_ADMIN_NAME: jloveless123
      SEMAPHORE_ADMIN_EMAIL: joe@joeloveless.com
      SEMAPHORE_ADMIN: jloveless123
    volumes:
      - semaphore-data:/etc/semaphore
      - ~/.ssh:/home/semaphore/.ssh
      - terraform-state:/terraform-state

volumes:
  semaphore-data:
    external: true
    name: docker_semaphore-data
  terraform-state:
```

### .env

```
SEMAPHORE_ADMIN_PASSWORD=<your-password>
```

### Important Notes

- **Always pin the volume as external** with the exact name from `docker volume ls`. This prevents data loss when restarting the container.
- **Never use `docker compose down -v`** -- the `-v` flag deletes volumes and wipes the database.
- The `SEMAPHORE_ADMIN` environment variables only create the admin account on first database initialization. If the database exists but you can't log in, create the user manually:

```bash
docker exec -it docker-semaphore-1 semaphore user add --admin --login jloveless123 --name jloveless123 --email joe@joeloveless.com --password <password>
```

### SSH Key Setup

The semaphore container runs as uid 1001. The SSH directory mounted from the host must be accessible:

```bash
# On the Semaphore VM, as root:
cp /path/to/id_semaphore /home/jloveless123/.ssh/
cp /path/to/id_semaphore.pub /home/jloveless123/.ssh/
chown -R 1001:0 /home/jloveless123/.ssh/
chmod 700 /home/jloveless123/.ssh/
chmod 600 /home/jloveless123/.ssh/id_semaphore
chmod 644 /home/jloveless123/.ssh/id_semaphore.pub
touch /home/jloveless123/.ssh/known_hosts
chown 1001:0 /home/jloveless123/.ssh/known_hosts
```

---

## 3. Semaphore Project Configuration

### Key Store

- **Name:** `Homelab SSH`
- **Type:** SSH Key
- **Private Key:** contents of `id_semaphore`

### Repository

- **Name:** `homelab`
- **URL:** Git repo SSH URL
- **Branch:** `main`
- **Access Key:** `Homelab SSH`

### Variable Group

- **Name:** `vg-pve00`

| Name | Value |
|---|---|
| `proxmox_api_host` | `https://<proxmox-ip>:8006` |
| `proxmox_api_user` | `terraform@pve` |
| `proxmox_api_token_id` | `terraform-token` |
| `proxmox_api_token_secret` | `<token-uuid>` |
| `proxmox_node` | `pve` |
| `template_name` | `<your-template-name>` |

### Inventory

- **Name:** `Homelab VMs`
- **Type:** File
- **Path:** `iac/semaphore/ansible/inventory/hosts.ini`
- **Repository:** `homelab`

---

## 4. Task Templates

### Terraform: Provision VM

- **Type:** Terraform
- **Name:** `pve00 - Provision Ubuntu VM`
- **Subdirectory:** `iac/semaphore/terraform`
- **Repository:** `homelab`
- **Variable Group:** `vg-pve00`
- **Survey Variables:** `vm_name` (prompted at runtime)
- **Auto approve:** unchecked (review plan before applying)

### Ansible: Set Hostname

- **Type:** Ansible
- **Name:** `Set Hostname`
- **Playbook:** `iac/semaphore/ansible/playbooks/set-hostname.yml`
- **Repository:** `homelab`
- **Inventory:** `Homelab VMs`
- **Survey Variables:** `new_hostname`, `target_hosts`

### Ansible: Update Ubuntu

- **Type:** Ansible
- **Name:** `Update Ubuntu`
- **Playbook:** `iac/semaphore/ansible/playbooks/update-ubuntu.yml`
- **Repository:** `homelab`
- **Inventory:** `Homelab VMs`

---

## 5. Provisioning Workflow

1. **Run "Provision VM"** template in Semaphore -- enter the VM name when prompted
2. Wait for Terraform to clone the template and boot the VM
3. Get the VM's DHCP IP from the Proxmox console
4. Add the VM to `iac/semaphore/ansible/inventory/hosts.ini`
5. **Run "Set Hostname"** template -- enter `target_hosts` (the new VM) and `new_hostname`
6. **Run "Update Ubuntu"** template to patch the new VM

---

## File Structure

```
iac/semaphore/
  terraform/
    providers.tf    # bpg/proxmox provider with API + SSH config
    variables.tf    # Input variables (credentials, VM sizing)
    main.tf         # VM clone resource
    backend.tf      # Local state backend (persisted via Docker volume)
  ansible/
    playbooks/
      set-hostname.yml    # Set hostname and reboot
      update-ubuntu.yml   # apt update/upgrade
    inventory/
      hosts.ini           # Static inventory of VMs
```

## Terraform State

State is stored at `/terraform-state/proxmox.tfstate` inside the container, backed by a Docker named volume. This persists across container restarts but is **not** backed up automatically. Consider periodically copying the state file:

```bash
docker cp docker-semaphore-1:/terraform-state/proxmox.tfstate ./backup-proxmox.tfstate
```
