#!/bin/bash

# ✅ REPLACE this with your actual dashboard IP
DASHBOARD_IP="198.7.118.95"

echo "🔧 Installing Docker, Docker Compose, UFW, and iptables-persistent..."
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

echo "🔁 Resetting and securing iptables DOCKER-USER chain..."

# Flush toàn bộ DOCKER-USER rules (xóa ACCEPT, DROP, RETURN cũ)
sudo iptables -F DOCKER-USER

# Đảm bảo DOCKER-USER được gọi trong chain FORWARD
sudo iptables -D FORWARD -j DOCKER-USER 2>/dev/null || true
sudo iptables -I FORWARD -j DOCKER-USER

# Thêm rule: chỉ cho phép DASHBOARD_IP truy cập port 61208
sudo iptables -I DOCKER-USER -p tcp -s $DASHBOARD_IP --dport 61208 -j ACCEPT

# Chặn tất cả các IP khác vào port 61208
sudo iptables -A DOCKER-USER -p tcp --dport 61208 -j DROP

echo "💾 Saving iptables rules..."
sudo netfilter-persistent save

echo "✅ Setup complete!"
echo "🌐 Access Glances at: http://$(hostname -I | awk '{print $1}'):61208 (only from $DASHBOARD_IP)"
echo "📋 UFW firewall status:"
sudo ufw status verbose
