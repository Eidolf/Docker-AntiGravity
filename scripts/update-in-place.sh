#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ -r "$SCRIPT_DIR/antigravity-version.sh" ]; then
    source "$SCRIPT_DIR/antigravity-version.sh"
else
    source /usr/local/lib/antigravity-version.sh
fi

INSTALL_DIR="${ANTIGRAVITY_INSTALL_DIR:-/opt/antigravity-desktop}"
LINK_PATH="${ANTIGRAVITY_EXECUTABLE_LINK:-/usr/local/bin/antigravity}"
LOCK_FILE="${ANTIGRAVITY_UPDATE_LOCK_FILE:-$HOME/.cache/antigravity-update.lock}"
mkdir -p "$(dirname -- "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock -x 9

TEMP_DIR=$(mktemp -d)
STAGING_DIR=""
BACKUP_DIR=""
cleanup() {
    local status=$?
    if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
        sudo rm -rf -- "$STAGING_DIR" || status=1
    fi
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        if [ ! -e "$INSTALL_DIR" ]; then
            if sudo mv -- "$BACKUP_DIR" "$INSTALL_DIR"; then
                BACKUP_DIR=""
            else
                echo "Error: Could not restore the previous Antigravity installation." >&2
                status=1
            fi
        else
            sudo rm -rf -- "$BACKUP_DIR" || status=1
        fi
    fi
    rm -rf -- "$TEMP_DIR" || status=1
    exit "$status"
}
trap cleanup EXIT

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
ARCHIVE="$TEMP_DIR/antigravity-hub.tar.gz"
curl -fsSL -o "$ARCHIVE" "https://storage.googleapis.com/antigravity-public/antigravity-hub/${HUB_VER}-${HUB_BUILD}/${ARCH_SUB}/Antigravity.tar.gz"
STAGING_DIR=$(sudo mktemp -d "${INSTALL_DIR}.staging.XXXXXX")
sudo tar -xzf "$ARCHIVE" -C "$STAGING_DIR" --strip-components=1
if [ ! -x "$STAGING_DIR/antigravity" ]; then
    echo "Error: The downloaded archive did not contain an executable Antigravity binary." >&2
    exit 1
fi

if [ -e "$INSTALL_DIR" ]; then
    BACKUP_DIR=$(sudo mktemp -d "${INSTALL_DIR}.backup.XXXXXX")
    sudo rmdir -- "$BACKUP_DIR"
    sudo mv -- "$INSTALL_DIR" "$BACKUP_DIR"
fi
if ! sudo mv -- "$STAGING_DIR" "$INSTALL_DIR"; then
    echo "Error: Could not install the new Antigravity files." >&2
    if [ -n "$BACKUP_DIR" ]; then
        sudo mv -- "$BACKUP_DIR" "$INSTALL_DIR"
        BACKUP_DIR=""
    fi
    exit 1
fi
STAGING_DIR=""
if [ -n "$BACKUP_DIR" ]; then
    sudo rm -rf -- "$BACKUP_DIR"
    BACKUP_DIR=""
fi
sudo ln -sf "$INSTALL_DIR/antigravity" "$LINK_PATH"
echo "Update complete! Please restart any running Antigravity instances."
read -r -p "Press Enter to exit..."
