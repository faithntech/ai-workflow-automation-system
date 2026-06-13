#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Stopping automatic apt services..."

sudo systemctl stop apt-daily.service apt-daily.timer || true
sudo systemctl stop apt-daily-upgrade.service apt-daily-upgrade.timer || true

echo "Waiting for apt locks..."

while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for dpkg lock..."
  sleep 5
done

while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  echo "Waiting for apt lists lock..."
  sleep 5
done

while sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
  echo "Waiting for apt cache lock..."
  sleep 5
done

echo "Updating packages..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

echo "Adding Docker GPG key..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "Adding Docker repository..."

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Installing Docker..."

sudo apt update -y

sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "Enabling Docker service..."

sudo systemctl enable docker
sudo systemctl start docker

echo "Adding ubuntu user to docker group..."

sudo usermod -aG docker ubuntu

echo "Docker installation completed!"

docker --version
docker compose version
