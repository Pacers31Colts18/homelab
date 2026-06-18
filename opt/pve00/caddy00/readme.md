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
sudo mkdir -p /opt/pve00/caddy00
echo "UUID=$(sudo blkid -s UUID -o value /dev/sdb) /opt/pve00/caddy00 ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown -R jloveless123:jloveless123 /opt/pve00/caddy00
```
## Configure Docker to use secondary disk
```bash
sudo mkdir -p /opt/pve00/caddy00/docker
sudo nano /etc/docker/daemon.json
```
Paste this, save with Ctrl+O then Ctrl+X:

```bash
{
  "data-root": "/opt/pve00/caddy00/docker"
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
## Caddy Setup
```bash
mkdir -p /opt/pve00/caddy00/docker
cd /opt/pve00/caddy00/docker
docker volume create caddy_data
```
### Create compose.yml:

```yml
services:
  caddy:
    image: ghcr.io/caddybuilds/caddy-cloudflare:latest
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
    env_file:
      - .env
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
    external: true
  caddy_config:
```

### Create .env:

```bash
CLOUDFLARE_API_TOKEN=your_token_here
```
### Create Caddyfile:

```bash
your.domain.com {
    reverse_proxy localhost:PORT
    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        resolvers 1.1.1.1
    }
}
```
docker compose up -d
docker compose logs -f caddy

## Adding a New Site

### Edit the Caddyfile and add a new block:

```bash
nano /opt/pve00/caddy00/docker/Caddyfile

newsite.joeloveless.net {
    reverse_proxy localhost:PORT
    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        resolvers 1.1.1.1
    }
}
```
## Reload Caddy (no restart needed):
```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```
## Syncing with GitHub

### Push changes (after editing files on Caddy host)
```bash
cp /opt/pve00/caddy00/docker/Caddyfile ~/homelab/opt/pve00/caddy00/docker/Caddyfile
cd ~/homelab
git add opt/pve00/caddy00/
git commit -m "update caddy config"
git push
```

### Pull changes (apply updates pushed from another machine)
```bash
cd ~/homelab
git pull
bash deploy.sh
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --force
```
