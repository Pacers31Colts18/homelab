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
sudo mkdir -p /opt/pve00/dns00
echo "UUID=$(sudo blkid -s UUID -o value /dev/sdb) /opt/pve00/dns00 ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown -R jloveless123:jloveless123 /opt/pve00/dns00
```
## Configure Docker to use secondary disk
```bash
sudo mkdir -p /opt/pve00/dns00/docker
sudo nano /etc/docker/daemon.json
```

Paste this, save with Ctrl+O then Ctrl+X:

```bash
{
  "data-root": "/opt/pve00/dns00/docker"
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
## Technitium Setup
```bash
mkdir -p /opt/pve00/dns00/docker
cd /opt/pve00/dns00/docker
docker volume create caddy_data
```
### Create compose.yml:

```yml
services:
  technitium:
    image: technitium/dns-server:latest
    container_name: Technitium
    healthcheck:
      test: timeout 10s bash -c ':> /dev/tcp/127.0.0.1/5380' || exit 1
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 90s
    hostname: dns00
    network_mode: host
    environment:
      DNS_SERVER_DOMAIN: joeloveless.net
      DNS_SERVER_LOG_USING_LOCAL_TIME: true
      TZ: America/Chicago
    volumes:
      - ./config:/etc/dns:rw
    restart: on-failure:5
```

## Committing to GitHub
```bash
cd ~/homelab
mkdir -p opt/pve00/dns00
cp /opt/pve00/dns00/readme.md opt/pve00/dns00/
cp /opt/pve00/dns00/docker/compose.yml opt/pve00/dns00/
git add opt/pve00/dns00/
git commit -m "Add Technitium config"
git push
```
