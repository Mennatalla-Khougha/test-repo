#!/bin/bash
# setup-press-vm.sh — v2.0 (Fixed swap & Node.js 20)
# For Frappe Press v15 on Ubuntu 22.04

set -e

echo "🚀 Starting setup-press-vm.sh v2.0..."

# 1. Update
sudo apt update

# 2. Set Timezone & Locale
sudo timedatectl set-timezone UTC
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# 3. Create Swap (only if none exists)
if [ ! -f /swapfile ] && [ "$(swapon --show)" = "" ]; then
    echo "Creating 2GB swap file..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
else
    echo "✅ Swap already configured — skipping."
fi

# 4. Harden SSH
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# 5. Install Tools
sudo apt install -y git curl wget htop ufw python3-pip python3-dev python3-venv \
    software-properties-common apt-transport-https ca-certificates redis-server

# 6. Install Node.js 20 (LTS — supported until 2028)
echo "Installing Node.js 20 (LTS)..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify
node --version  # Should be v20.x

# 7. Start Redis
sudo systemctl enable --now redis-server

# 8. Install Docker (for future build server)
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker "$USER"

# 9. Configure UFW
sudo ufw --force reset
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 9000/tcp   # Press API
sudo ufw allow 8000/tcp   # Bench dev
sudo ufw --force enable

# 10. Set Hostname
sudo hostnamectl set-hostname press.local
echo "127.0.0.1 localhost" | sudo tee /etc/hosts > /dev/null
echo "127.0.0.1 press.local" | sudo tee -a /etc/hosts
# Keep NAT IP for now — will change later
ip=$(hostname -I | awk '{print $1}')
echo "$ip press.local" | sudo tee -a /etc/hosts

# 11. Ensure frappe user in sudoers
if ! sudo grep -q "^frappe" /etc/sudoers.d/frappe 2>/dev/null; then
    echo "frappe ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/frappe
fi

# 12. Install bench dependencies
pip3 install --user frappe-bench

echo "✅ setup-press-vm.sh v2.0 completed!"
echo "👉 Run: bench init --frappe-branch version-15 frappe-bench"
