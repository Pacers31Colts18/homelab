## Install packages
- Docker
- GitHub CLI
- Tailscale

```bash
sudo apt-get update && sudo apt-get upgrade -y && \
sudo apt-get install -y curl gnupg apt-transport-https ca-certificates lsb-release git && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg && \
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli.gpg && \
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | sudo gpg --dearmor -o /usr/share/keyrings/tailscale.gpg && \
echo "deb [signed-by=/usr/share/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null && \
sudo apt-get update && \
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin gh tailscale && \
sudo systemctl enable --now docker tailscaled && \
sudo usermod -aG docker "$USER"
```

## Set up secondary disk
```bash
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /opt/pve00/semaphore00
echo "UUID=$(sudo blkid -s UUID -o value /dev/sdb) /opt/pve00/semaphore00 ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown -R jloveless123:jloveless123 /opt/pve00/semaphore00
```
## Configure Docker to use secondary disk
```bash
sudo mkdir -p /opt/pve00/semaphore00/docker
sudo nano /etc/docker/daemon.json
```
Paste this, save with Ctrl+O then Ctrl+X:

```bash
{
  "data-root": "/opt/pve00/semaphore00/docker"
}
```
```bash
sudo systemctl restart docker
docker info | grep "Docker Root Dir"
```

Log out and back in
Required for Docker group to take effect.

## Connect Tailscale (optional)
```bash
sudo tailscale up
```
## Semaphore Setup
```bash
mkdir -p /opt/pve00/semaphore00/docker
cd /opt/pve00/semaphore00/docker
docker volume create semaphore_data
```
### Create compose.yml:

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
      - ~/.ssh:/home/semaphore/.ssh:ro

volumes:
  semaphore-data:
```

### Create .env:

```bash
SEMAPHORE_ADMIN_PASSWORD=your-admin-password
SEMAPHORE_ACCESS_KEY_ENCRYPTION=your-base64-encryption-key
```

Generate the encryption key with:
```bash
head -c32 /dev/urandom | base64
```

### Start Semaphore:
```bash
docker compose up -d
```

## Target Host Setup

On each host you want to manage with Semaphore:

### Create the semaphore user:
```bash
sudo adduser semaphore
sudo usermod -aG sudo semaphore
```

### Enable passwordless sudo:
```bash
sudo visudo
```
Add at the bottom:
```
semaphore ALL=(ALL) NOPASSWD: ALL
```

### Copy SSH key to the new user:
```bash
sudo mkdir -p /home/semaphore/.ssh
sudo cp ~/.ssh/authorized_keys /home/semaphore/.ssh/
sudo chown -R semaphore:semaphore /home/semaphore/.ssh
sudo chmod 700 /home/semaphore/.ssh
sudo chmod 600 /home/semaphore/.ssh/authorized_keys
```

## Semaphore UI Setup

### 1. Key Store
Add your SSH private key (`cat ~/.ssh/id_ed25519`), including the `BEGIN` and `END` lines.

### 2. Environment
Create one named "Default" (can be empty).

### 3. Inventory
Create new, type Static, format YAML:
```yaml
all:
  hosts:
    dns00:
      ansible_host: 192.168.4.42
      ansible_user: semaphore
```

### 4. Repository
Point to your homelab repo and select the SSH key from the Key Store.

### 5. Task Template
- Name: Update Ubuntu
- Playbook: path to your playbook (e.g. `playbooks/update-ubuntu.yml`)
- Inventory: select the one you created
- Environment: select the one you created

## Playbooks

### Update Ubuntu (`playbooks/update-ubuntu.yml`):
```yaml
---
- name: Update Ubuntu
  hosts: all
  become: true
  tasks:
    - name: Update apt cache
      apt:
        update_cache: true

    - name: Upgrade all packages
      apt:
        upgrade: dist

    - name: Remove unused packages
      apt:
        autoremove: true
        purge: true

    - name: Check if reboot is required
      stat:
        path: /var/run/reboot-required
      register: reboot_required

    - name: Reboot if required
      reboot:
      when: reboot_required.stat.exists
```

## Logs
```bash
docker logs -f semaphore
docker logs --tail 100 semaphore
```

## Syncing with GitHub

### Push changes (after editing files on this host)
```bash
cd ~/homelab
git add opt/pve00/semaphore00/
git commit -m "update semaphore config"
git push
```

### Pull changes (apply updates pushed from another machine)
```bash
cd ~/homelab
git pull
bash deploy.sh
```
