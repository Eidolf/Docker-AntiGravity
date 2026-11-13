#!/bin/bash
# AntiGravity Host Update Utility — VSCode Edition
# Fetches the latest release information and rebuilds the container.

set -e

echo "=== AntiGravity Host Update Utility (VSCode Edition) ==="

# Fetch latest Antigravity Hub version via Homebrew Cask
echo "Fetching latest Antigravity Hub version from Homebrew Cask..."
VERSION=$(python3 -c '
import urllib.request, re
try:
    url = "https://raw.githubusercontent.com/Homebrew/homebrew-cask/main/Casks/a/antigravity.rb"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as response:
        content = response.read().decode("utf-8")
        match = re.search(r"version\s+\"([^\"]+)\"", content)
        if match:
            parts = match.group(1).split(",")
            if len(parts) == 2:
                print(f"{parts[0]}|{parts[1]}")
except Exception as e:
    print(f"Error fetching antigravity: {e}")
')

HUB_VER=$(echo "$VERSION" | cut -d'|' -f1)
HUB_BUILD=$(echo "$VERSION" | cut -d'|' -f2)

if [ -z "$HUB_VER" ] || [ -z "$HUB_BUILD" ]; then
    echo "Error: Failed to fetch version info. Please enter versions manually:"
    read -p "Antigravity Hub Version (e.g. 2.1.4): " HUB_VER
    read -p "Antigravity Hub Build ID (e.g. 6481382726303744): " HUB_BUILD
fi

echo "Latest Antigravity Hub: $HUB_VER (Build: $HUB_BUILD)"
echo ""

# Check current Dockerfile values
CURRENT_HUB_VER=$(grep "ENV ANTIGRAVITY_HUB_VERSION=" Dockerfile | cut -d'=' -f2)
CURRENT_HUB_BUILD=$(grep "ENV ANTIGRAVITY_HUB_BUILD=" Dockerfile | cut -d'=' -f2)

echo "Current Dockerfile versions:"
echo "  Antigravity Hub: $CURRENT_HUB_VER (Build: $CURRENT_HUB_BUILD)"
echo ""

if [ "$HUB_VER" = "$CURRENT_HUB_VER" ] && [ "$HUB_BUILD" = "$CURRENT_HUB_BUILD" ]; then
    echo "Dockerfile is already at the latest Antigravity version."
    read -p "Force rebuild anyway? (y/N): " FORCE_REBUILD
    if [[ ! "$FORCE_REBUILD" =~ ^[yY]$ ]]; then
        echo "Exiting."
        exit 0
    fi
else
    read -p "Update Dockerfile and rebuild the container? (y/N): " PROCEED
    if [[ ! "$PROCEED" =~ ^[yY]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    echo "Updating Dockerfile variables..."
    sed -i "s/ENV ANTIGRAVITY_HUB_VERSION=.*/ENV ANTIGRAVITY_HUB_VERSION=$HUB_VER/" Dockerfile
    sed -i "s/ENV ANTIGRAVITY_HUB_BUILD=.*/ENV ANTIGRAVITY_HUB_BUILD=$HUB_BUILD/" Dockerfile
fi

echo "Rebuilding and restarting the Docker container..."
docker compose build --no-cache
docker compose up -d

echo ""
echo "=== Update Successful! ==="
