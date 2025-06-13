#!/bin/bash

# :warning: Replace this with your actual dashboard server IP
DASHBOARD_IP="198.7.118.95"  # ← REPLACE this with your actual IP

echo "🔧 Installing Docker and Docker Compose..."
sudo apt update -y
sudo apt install -y docker.io docker-compose ufw curl

echo "🚀 Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "📁 Creating Glances folder and docker-compose.yml..."
mkdir -p ~/glances-docker
cat > ~/glances-docker/docker-compose.yml <<EOF
version: '3.8'

services:
  glances:
    image: nicolargo/glances:latest
    container_name: glances
    restart: unless-stopped
    ports:
      - "61208:61208"
    environment:
      - GLANCES_OPT=-w --disable-plugin containers
    pid: "host"
    privileged: true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /:/host:ro
EOF

echo "🐳 Starting Glances with Docker Compose..."
cd ~/glances-docker
sudo docker compose up -d

echo "🛡️ Configuring UFW firewall rules..."
sudo ufw allow OpenSSH
sudo ufw --force enable

echo "🚫 Blocking all other IPs from accessing port 61208..."
sudo ufw delete allow 61208 2>/dev/null || true
sudo ufw deny 61208/tcp

echo "✅ Allowing dashboard IP $DASHBOARD_IP to access port 61208..."
sudo ufw allow from $DASHBOARD_IP to any port 61208 proto tcp

echo "✅ Done! Glances is now running at: http://$(hostname -I | awk '{print $1}'):61208"
echo "📋 UFW firewall status:"
sudo ufw status verbose

# Save this script for GitHub or future reuse
echo "💾 Saving this setup script to ~/setup_glances.sh..."
cp $0 ~/setup_glances.sh
chmod +x ~/setup_glances.sh
