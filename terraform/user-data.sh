#!/bin/bash

# ==========================================
# AI Workflow Automation Project
# User Data Script
#
# Purpose:
# 1. Install Docker
# 2. Install Docker Compose
# 3. Install Nginx
# 4. Deploy n8n
# 5. Configure Reverse Proxy
# 6. Generate SSL Certificate
# ==========================================

# Prevent package installation prompts
export DEBIAN_FRONTEND=noninteractive

# Stop automatic Ubuntu package updates
# This avoids conflicts during provisioning
echo "Stopping automatic apt services..."

sudo systemctl stop apt-daily.service apt-daily.timer || true
sudo systemctl stop apt-daily-upgrade.service apt-daily-upgrade.timer || true

# Wait until package manager locks are released
echo "Waiting for apt locks..."

# Wait for dpkg lock
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for dpkg lock..."
  sleep 5
done

# Wait for apt lists lock
while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  echo "Waiting for apt lists lock..."
  sleep 5
done

# Wait for apt cache lock
while sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
  echo "Waiting for apt cache lock..."
  sleep 5
done

# Update package repositories
echo "Updating packages..."

sudo apt update -y
sudo apt upgrade -y

# Install required dependencies
echo "Installing dependencies..."

sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  nginx

# Create Docker key directory
echo "Adding Docker GPG key..."

sudo mkdir -p /etc/apt/keyrings

# Download Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set correct permissions
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "Adding Docker repository..."

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Refresh package cache
sudo apt update -y

# Install Docker components
echo "Installing Docker..."

sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable Docker service
echo "Enabling Docker service..."

sudo systemctl enable docker
sudo systemctl start docker

# Allow ubuntu user to run docker commands
echo "Adding ubuntu user to docker group..."

sudo usermod -aG docker ubuntu

# Display Docker versions
docker --version
docker compose version

# ==========================================
# PROJECT VARIABLES
# ==========================================

# Domain name used for n8n
DOMAIN="n8n.shielacloudevops.work"

# Email used for SSL certificate registration
EMAIL="lulu.n8n@gmail.com"

# ==========================================
# CREATE APPLICATION DIRECTORY
# ==========================================

echo "Creating n8n directory..."

mkdir -p /home/ubuntu/n8n

cd /home/ubuntu/n8n

# ==========================================
# CREATE DOCKER COMPOSE FILE
# ==========================================

echo "Creating docker-compose.yml..."

cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always

    # Only expose locally
    ports:
      - "127.0.0.1:5678:5678"

    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - WEBHOOK_URL=https://${DOMAIN}/
      - N8N_EDITOR_BASE_URL=https://${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Manila
      - TZ=Asia/Manila
      - N8N_PROXY_HOPS=1
      - N8N_SECURE_COOKIE=true
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=lulu.n8n@gmail.com
      - N8N_PASS=Admin123456

# n8n connection
    extra_hosts:
      - "host.docker.internal:host-gateway"

    volumes:
      - n8n_data:/home/node/.n8n

    depends_on:
      - postgres

  postgres:
    image: postgres:16
    container_name: postgres

    restart: always

    environment:
      POSTGRES_DB: automation_db
      POSTGRES_USER: automation_user
      POSTGRES_PASSWORD: StrongPassword123

    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  n8n_data:
  postgres_data:
EOF

# ==========================================
# START N8N CONTAINER
# ==========================================

echo "Starting n8n..."

docker compose up -d

# ==========================================
# CREATE NGINX REVERSE PROXY
# ==========================================

echo "Creating nginx configuration..."

cat > /etc/nginx/sites-available/n8n <<EOF
server {

    # Listen on HTTP
    listen 80;

    # Domain name
    server_name ${DOMAIN};

    location / {

        # Forward traffic to n8n
        proxy_pass http://127.0.0.1:5678;

        proxy_http_version 1.1;

        # Enable websocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Forward original headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_buffering off;
# fix for code error 414 OAuth authorization error, request header too large
	client_header_buffer_size 16k; 
	large_client_header_buffers 4 32k; 
	proxy_buffer_size 128k; proxy_buffers 4 256k; 
	proxy_busy_buffers_size 256k;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# Remove default Nginx site
rm -f /etc/nginx/sites-enabled/default

# Validate Nginx configuration
nginx -t

# Reload Nginx
systemctl reload nginx

# ==========================================
# INSTALL CERTBOT SSL
# ==========================================

echo "Installing Certbot..."

apt install -y certbot python3-certbot-nginx

# Generate SSL certificate automatically
echo "Generating SSL certificate..."

certbot --nginx \
  -d ${DOMAIN} \
  --non-interactive \
  --agree-tos \
  -m ${EMAIL} \
  --redirect || true

# Reload Nginx after SSL installation
systemctl reload nginx

# ==========================================
# DEPLOYMENT COMPLETE
# ==========================================

echo "==================================="
echo "Deployment Completed Successfully"
echo "==================================="

echo "Access n8n at:"
echo "https://${DOMAIN}"
