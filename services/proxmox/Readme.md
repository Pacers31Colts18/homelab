# Proxmox Infrastructure Documentation

## Hosts

| Host | Role | IP Address |
|------|------|------------|
| pve00 | Proxmox VE Node | 192.168.4.2 |
| pve01 | Proxmox VE Node | 192.168.4.3 |
| pbs00 | Proxmox Backup Server | 192.168.4.4 |

## Virtual Machines

| VM ID | Node | Name | Type |
|-------|------|------|------|
| 100 | pve00 | caddy00 | Virtual Machine |
| 101 | pve00 | homeassistant00 | Virtual Machine |
| 102 | pve00 | semaphore00 | Virtual Machine |
| 103 | pve01 | dns01 | Virtual Machine |
| 104 | pve00 | dns00 | Virtual Machine |
| 105 | pve01 | pulse01 | Virtual Machine |
| 998 | pve00 | pve00-template | Virtual Machine |
| 999 | pve01 | VM 999 | Virtual Machine |

## Networking

### DNS

- **Software**: Technitium DNS Server (Docker)
- **Primary**: dns00 — 192.168.4.7 (pve00)
- **Secondary**: dns01 — 192.168.4.8 (pve01)
- **Domain**: joeloveless.net (websites)
- **Internal Domain**: int.joeloveless.net (SSH, internal configurations)
- **DHCP**: Eero router distributes DNS servers to clients

### Reverse Proxy

- **Software**: Caddy (VM 100 — caddy00)

## Backup Strategy

### Daily Backups — Proxmox Backup Server (PBS)

| Setting | Value |
|---------|-------|
| Storage ID | pve-backups |
| Server | 192.168.4.4 (pbs00) |
| Datastore | pve-backups |
| Schedule | Daily at 22:00 |
| Mode | Snapshot |
| Compression | ZSTD |
| Selection | All VMs |
| Nodes | All |

### PBS Retention & Pruning

| Setting | Value |
|---------|-------|
| Keep Last | 3 |
| Keep Daily | 7 |
| Keep Weekly | 4 |
| Keep Monthly | 2 |
| Prune Schedule | Daily at 21:30 |
| Garbage Collection | Sundays at 02:00 |

### Monthly Archive — UGreen NAS

| Setting | Value |
|---------|-------|
| NAS IP | 192.168.4.125 |
| Storage Type | NFS |
| NFS Export | /volume1/share |
| Storage ID | nas-monthly |
| Schedule | 1st of each month at 04:00 |
| Mode | Snapshot |
| Selection | All VMs |
| Retention | Keep Monthly: 12 |
| Backup Format | VZDump (.vma.dat) |

### Backup Flow

```
Daily at 22:00          Monthly on the 1st at 04:00
PVE Nodes ──────────►  PBS (pve-backups)
    │                   - 7 daily, 4 weekly, 2 monthly
    │
    └───────────────►  UGreen NAS (nas-monthly)
                        - 12 monthly archives
```

### NFS Configuration (UGreen NAS)

- NFS rules configured per host IP (not wildcard)
- Permissions: Read/Write
- Squash: No mapping (equivalent to no_root_squash)
- Allowed clients: 192.168.4.2, 192.168.4.3, 192.168.4.4

## Services

| Service | VM/Host | IP | Port | Notes |
|---------|---------|----|------|-------|
| Caddy (reverse proxy) | caddy00 (VM 100) | — | 443 | HTTP/3 enabled |
| Home Assistant | homeassistant00 (VM 101) | — | — | |
| Semaphore | semaphore00 (VM 102) | 192.168.4.25 | 3000 | Ansible UI, Docker |
| Technitium DNS | dns00 (VM 104) | 192.168.4.7 | 53, 5380 | Docker, host networking |
| Technitium DNS | dns01 (VM 103) | 192.168.4.8 | 53, 5380 | Docker, host networking |
| Pulse Monitoring | pulse01 (VM 105) | — | — | |
