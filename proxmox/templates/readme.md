# Ubuntu Cloud-Init Template

## Download Cloud Image
```bash
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64v3.img
```

## Create the VM
```bash
qm create 999 --memory 2048 --cores 2 --cpu x86-64-v2-AES --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci
```

## Import and Attach Boot Disk
```bash
qm importdisk 999 /var/lib/vz/template/iso/ubuntu-26.04-server-cloudimg-amd64v3.img local-lvm
qm set 999 --scsi0 local-lvm:vm-999-disk-0
qm resize 999 scsi0 20G
```

## Add Second Disk (16GB)
```bash
qm set 999 --scsi1 local-lvm:16
```

## Add Cloud-Init Drive and Set Boot Order
```bash
qm set 999 --ide2 local-lvm:cloudinit
qm set 999 --boot order=scsi0
```

## Cloud-Init Snippet (Semaphore User)

### Enable snippets on storage:
```bash
pvesm set local --content images,rootdir,vztmpl,backup,iso,snippets
```

### Create the snippet:
```bash
nano /var/lib/vz/snippets/semaphore-user.yml
```

```yaml
#cloud-config
users:
  - default
  - name: semaphore
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 AAAA...your-public-key-here
```

### Attach to the VM:
```bash
qm set 999 --cicustom "vendor=local:snippets/semaphore-user.yml"
```

## Set Default Cloud-Init User
```bash
qm set 999 --ciuser jloveless123
qm set 999 --sshkeys ~/.ssh/id_ed25519.pub
```

## Convert to Template
```bash
qm template 999
```

## Clone a New VM from Template
```bash
qm clone 999 <vmid> --name <hostname> --full
qm set <vmid> --ipconfig0 ip=192.168.4.x/24,gw=192.168.4.1
qm start <vmid>
```
