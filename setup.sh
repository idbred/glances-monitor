#!/bin/bash

# :warning: Replace this with your actual dashboard server IP
DASHBOARD_IP="198.7.118.95"

echo "🔧 Installing Docker and Docker Compose..."
sudo apt update -y
sudo apt install -y docker.io docker-compose ufw curl iptables-persistent -y

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
      - GLANCES_OPT=-w -B 0.0.0.0 --disable-plugin containers
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
sudo ufw delete allow 61208 2>/dev/null || true
sudo ufw deny 61208/tcp
sudo ufw allow from $DASHBOARD_IP to any port 61208 proto tcp
sudo ufw --force enable

echo "🛡️ Setting iptables rules for Docker (DOCKER-USER chain)..."
# Xoá rule cũ (nếu có)
sudo iptables -D DOCKER-USER -p tcp -s $DASHBOARD_IP --dport 61208 -j ACCEPT 2>/dev/null || true
sudo iptables -D DOCKER-USER -p tcp --dport 61208 -j DROP 2>/dev/null || true

# Thêm rule mới đúng thứ tự
sudo iptables -I DOCKER-USER -p tcp -s $DASHBOARD_IP --dport 61208 -j ACCEPT
sudo iptables -A DOCKER-USER -p tcp --dport 61208 -j DROP

# Lưu lại iptables
sudo netfilter-persistent save

echo "✅ Setup complete!"
echo "🌐 Access Glances at: http://$(hostname -I | awk '{print $1}'):61208 (only from $DASHBOARD_IP)"
echo "📋 UFW firewall status:"
sudo ufw status verbose
