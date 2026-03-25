#!/bin/bash

# AntiGravity Automated Setup Script
# Works on both x86_64 (amd64) and aarch64 (arm64)

set -e

echo "--- AntiGravity Setup ---"

# 1. Detect Architecture
ARCH=$(dpkg --print-architecture || uname -m)
case $ARCH in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"

# 2. Build Docker Image locally
echo "Building Docker image locally (this may take a few minutes)..."
docker build -t docker-antigravity:latest .

# 3. Generate docker-compose.yml
echo "Generating docker-compose.yml..."
cat <<EOF > docker-compose.yml
name: antigravity

services:
  antigravity-desktop:
    image: docker-antigravity:latest
    container_name: antigravity-desktop
    ports:
      - "\${HOST_WEB_PORT:-6080}:6080" # NoVNC web access
      - "\${HOST_VNC_PORT:-5901}:5901" # VNC direct access
    shm_size: "2gb"
    privileged: true
    volumes:
      - antigravity-home:/home/dev
      - antigravity-workspace:/home/dev/workspace
      - antigravity-docker-data:/var/lib/docker
    networks:
      - antigravity-network
    restart: unless-stopped

volumes:
  antigravity-home:
    name: antigravity-home
  antigravity-workspace:
    name: antigravity-workspace
  antigravity-docker-data:
    name: antigravity-docker-data

networks:
  antigravity-network:
    name: antigravity-network
EOF

echo "--- Setup Complete ---"
echo "You can now start AntiGravity by running:"
echo "  docker compose up -d"
echo ""
echo "Access the web interface at: http://localhost:6080"
