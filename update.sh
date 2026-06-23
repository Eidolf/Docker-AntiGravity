#!/bin/bash
# AntiGravity Update Script (Host-side)
# Fetches the latest release information and rebuilds the container.

set -e

echo "=== AntiGravity Host Update Utility ==="

# Fetch latest version info using Python
echo "Fetching latest version info from Homebrew Casks..."
VERSIONS=$(python3 -c '
import urllib.request, re
def get_cask_ver(cask):
    try:
        url = f"https://raw.githubusercontent.com/Homebrew/homebrew-cask/main/Casks/a/{cask}.rb"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as response:
            content = response.read().decode("utf-8")
            match = re.search(r"version\s+\"([^\"]+)\"", content)
            if match:
                parts = match.group(1).split(",")
                if len(parts) == 2:
                    return parts[0], parts[1]
    except Exception as e:
        print(f"Error fetching {cask}: {e}")
    return None, None

hub_v, hub_b = get_cask_ver("antigravity")
ide_v, ide_b = get_cask_ver("antigravity-ide")
print(f"{hub_v}|{hub_b}|{ide_v}|{ide_b}")
')

HUB_VER=$(echo "$VERSIONS" | cut -d'|' -f1)
HUB_BUILD=$(echo "$VERSIONS" | cut -d'|' -f2)
IDE_VER=$(echo "$VERSIONS" | cut -d'|' -f3)
IDE_BUILD=$(echo "$VERSIONS" | cut -d'|' -f4)

if [ -z "$HUB_VER" ] || [ -z "$HUB_BUILD" ] || [ -z "$IDE_VER" ] || [ -z "$IDE_BUILD" ]; then
    echo "Error: Failed to fetch version info. Please enter versions manually:"
    read -p "Antigravity Hub Version (e.g. 2.1.4): " HUB_VER
    read -p "Antigravity Hub Build ID (e.g. 6481382726303744): " HUB_BUILD
    read -p "Antigravity IDE Version (e.g. 2.1.1): " IDE_VER
    read -p "Antigravity IDE Build ID (e.g. 6123990880747520): " IDE_BUILD
fi

echo "Latest versions found:"
echo "  Antigravity Hub: $HUB_VER (Build: $HUB_BUILD)"
echo "  Antigravity IDE: $IDE_VER (Build: $IDE_BUILD)"
echo ""

# Check current variables in Dockerfile
CURRENT_HUB_VER=$(grep "ENV ANTIGRAVITY_HUB_VERSION=" Dockerfile | cut -d'=' -f2)
CURRENT_IDE_VER=$(grep "ENV ANTIGRAVITY_IDE_VERSION=" Dockerfile | cut -d'=' -f2)

echo "Current local Dockerfile versions:"
echo "  Antigravity Hub: $CURRENT_HUB_VER"
echo "  Antigravity IDE: $CURRENT_IDE_VER"
echo ""

if [ "$HUB_VER" = "$CURRENT_HUB_VER" ] && [ "$IDE_VER" = "$CURRENT_IDE_VER" ]; then
    echo "Your Dockerfile is already configured with the latest versions."
    read -p "Do you still want to force rebuild the Docker container? (y/N): " FORCE_REBUILD
    if [[ ! "$FORCE_REBUILD" =~ ^[yY]$ ]]; then
        echo "Exiting."
        exit 0
    fi
else
    read -p "Do you want to update the Dockerfile and rebuild the container? (y/N): " PROCEED
    if [[ ! "$PROCEED" =~ ^[yY]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    # Update Dockerfile
    echo "Updating Dockerfile variables..."
    sed -i "s/ENV ANTIGRAVITY_HUB_VERSION=.*/ENV ANTIGRAVITY_HUB_VERSION=$HUB_VER/" Dockerfile
    sed -i "s/ENV ANTIGRAVITY_HUB_BUILD=.*/ENV ANTIGRAVITY_HUB_BUILD=$HUB_BUILD/" Dockerfile
    sed -i "s/ENV ANTIGRAVITY_IDE_VERSION=.*/ENV ANTIGRAVITY_IDE_VERSION=$IDE_VER/" Dockerfile
    sed -i "s/ENV ANTIGRAVITY_IDE_BUILD=.*/ENV ANTIGRAVITY_IDE_BUILD=$IDE_BUILD/" Dockerfile
fi

echo "Rebuilding and restarting the Docker container..."
docker compose build --no-cache
docker compose up -d

echo ""
echo "=== Update Successful! ==="
