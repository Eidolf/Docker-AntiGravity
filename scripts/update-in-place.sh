#!/bin/bash
set -e

source /usr/local/lib/antigravity-version.sh

echo "Checking architecture..."
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "amd64" ]; then
    ARCH_SUB="linux-x64"
else
    ARCH_SUB="linux-arm"
fi

echo "Fetching latest version from Homebrew Cask..."
if ! VERSION=$(python3 -c '
import re, sys, urllib.request
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
except Exception as error:
    print(f"Error: {error}", file=sys.stderr)
'); then
    echo "Error: Version discovery failed; falling back to manual entry." >&2
    VERSION=""
fi

if [[ "$VERSION" == *"|"* ]]; then
    HUB_VER="${VERSION%%|*}"
    HUB_BUILD="${VERSION#*|}"
else
    HUB_VER=""
    HUB_BUILD=""
fi

if ! validate_antigravity_hub_values "$HUB_VER" "$HUB_BUILD"; then
    echo "Error: Failed to fetch valid version info. Please enter versions manually:" >&2
    if ! read_manual_antigravity_hub_values; then
        echo "Error: Valid version and build ID are required." >&2
        exit 1
    fi
fi

echo "Updating Antigravity to $HUB_VER (Build $HUB_BUILD)..."
curl -fsSL -o /tmp/antigravity-hub.tar.gz "https://storage.googleapis.com/antigravity-public/antigravity-hub/${HUB_VER}-${HUB_BUILD}/${ARCH_SUB}/Antigravity.tar.gz"
sudo rm -rf /opt/antigravity-desktop/*
sudo tar -xzf /tmp/antigravity-hub.tar.gz -C /opt/antigravity-desktop --strip-components=1
rm /tmp/antigravity-hub.tar.gz
sudo ln -sf /opt/antigravity-desktop/antigravity /usr/local/bin/antigravity
echo "Update complete! Please restart any running Antigravity instances."
read -r -p "Press Enter to exit..."
