# Installs Docker, GitHub CLI, and TailScale.

sudo apt-get update && sudo apt-get upgrade -y && \
sudo apt-get install -y curl gnupg apt-transport-https ca-certificates lsb-release git && \

# Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg && \
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli.gpg && \
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \

# Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | sudo gpg --dearmor -o /usr/share/keyrings/tailscale.gpg && \
echo "deb [signed-by=/usr/share/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null && \

sudo apt-get update && \
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin gh tailscale && \
sudo systemctl enable --now docker tailscaled && \
sudo usermod -aG docker "$USER" && \
echo "Done. Run: sudo tailscale up | gh auth login"
