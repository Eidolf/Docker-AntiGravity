#!/bin/bash
set -e

# Mask WSL detection
if [ -f /etc/fake_version ]; then
    mount --bind /etc/fake_version /proc/version || true
fi
if [ -f /etc/fake_osrelease ]; then
    mount --bind /etc/fake_osrelease /proc/sys/kernel/osrelease || true
fi

# Dynamic Package Installation
PACKAGES_TO_INSTALL=""

if [ "$INSTALL_ANDROID_TOOLS" = "true" ]; then
    echo "Creating Android tools installation list..."
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL android-sdk-platform-tools-common adb fastboot"
fi

if [ "$INSTALL_DEV_TOOLS" = "true" ]; then
    echo "Creating Dev tools installation list..."
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL build-essential cmake gdb clang"
fi

if [ "$INSTALL_WINDOWS_TOOLS" = "true" ]; then
    echo "Creating Windows cross-compilation tools installation list..."
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL mingw-w64"
fi

if [ -n "$ADDITIONAL_PACKAGES" ]; then
    echo "Adding custom packages: $ADDITIONAL_PACKAGES"
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $ADDITIONAL_PACKAGES"
fi

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installing additional packages: $PACKAGES_TO_INSTALL"
    apt-get update
    # shellcheck disable=SC2086
    apt-get install -y $PACKAGES_TO_INSTALL
    apt-get clean && rm -rf /var/lib/apt/lists/*
fi

# Fix permissions for /home/dev (in case of volume mount issues)
echo "Fixing permissions for /home/dev..."
chown -R dev:dev /home/dev


# Configure Docker Storage Driver (Auto-detect environment)
if [ ! -f /etc/docker/daemon.json ]; then
    echo "Configuring Docker storage driver..."
    if command -v fuse-overlayfs >/dev/null 2>&1; then
        echo "Detected fuse-overlayfs, configuring as storage driver..."
        sudo mkdir -p /etc/docker
        echo '{"storage-driver": "fuse-overlayfs"}' | sudo tee /etc/docker/daemon.json > /dev/null
    else
        echo "fuse-overlayfs not found. Using default driver."
    fi
fi

# Start Docker Daemon
if [ -f /var/run/docker.pid ]; then
    sudo rm /var/run/docker.pid
fi
sudo service docker start
echo "Waiting for Docker to start..."
while ! sudo docker info >/dev/null 2>&1; do
    sleep 1
done
echo "Docker started."

# Remove any existing VNC locks and Chrome locks
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1
rm -f /home/dev/.config/google-chrome/SingletonLock

# Generate or recover VNC_PASSWORD
if [ -z "$VNC_PASSWORD" ]; then
    if [ -f /home/dev/.vnc/passwd_clear ]; then
        echo "Example: Persistent password file found. Recovering..."
        VNC_PASSWORD=$(cat /home/dev/.vnc/passwd_clear)
    elif [ -f /home/dev/.vnc/passwd ]; then
        echo "Warning: VNC password hash exists but cleartext missing. Regenerating to ensure sync."
        VNC_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
    else
        VNC_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
    fi
fi

# Set VNC password and system password
if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /home/dev/.vnc
    
    # Save cleartext for persistence restoration
    echo "$VNC_PASSWORD" > /home/dev/.vnc/passwd_clear
    chmod 600 /home/dev/.vnc/passwd_clear
    chown dev:dev /home/dev/.vnc/passwd_clear

    echo "$VNC_PASSWORD" | vncpasswd -f > /home/dev/.vnc/passwd
    chmod 600 /home/dev/.vnc/passwd
    chown dev:dev /home/dev/.vnc/passwd

    # Set user password (crucial for screen unlocking)
    echo "dev:$VNC_PASSWORD" | sudo chpasswd
fi

# Export VNC_PASSWORD so vnc_startup.sh can use it to unlock keyring
export VNC_PASSWORD

# Ensure vnc_startup.sh is used
if [ ! -f /home/dev/.vnc/xstartup ]; then
    ln -s /usr/local/bin/vnc_startup.sh /home/dev/.vnc/xstartup
fi

# Start VNC Server
# Start VNC Server
echo "Starting VNC Server..."
gosu dev vncserver :1 -geometry 1920x1080 -depth 24 -localhost no

# Start NoVNC Proxy
echo "Starting NoVNC..."

# Display access URLs
echo ""
echo "=============================================="
echo "  AntiGravity Desktop is ready!"
echo "=============================================="
echo ""
echo "  Access via browser:"
echo "    http://localhost:6080/vnc.html"
echo ""
echo "  Direct VNC connection:"
echo "    localhost:5901"
echo ""
if [ -n "$VNC_PASSWORD" ]; then
    echo "  GENERATED PASSPHRASE:"
    echo "    $VNC_PASSWORD"
else
    echo "  PASSPHRASE:"
    echo "    (Existing persistent password used)"
fi
echo ""
echo "=============================================="
echo ""

# Pointing websockify to the VNC server port 5901
# Pointing websockify to the VNC server port 5901
gosu dev /usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080
