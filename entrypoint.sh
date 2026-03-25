#!/bin/bash
# AntiGravity Entrypoint Script

# Function for robust logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Mask WSL detection (optional, ignore errors)
log "Applying system masks..."
if [ -f /etc/fake_version ]; then
    mount --bind /etc/fake_version /proc/version || log "Warning: Could not mask /proc/version"
fi
if [ -f /etc/fake_osrelease ]; then
    mount --bind /etc/fake_osrelease /proc/sys/kernel/osrelease || log "Warning: Could not mask /proc/sys/kernel/osrelease"
fi

# Dynamic Package Installation (Non-blocking)
PACKAGES_TO_INSTALL=""

if [ "$INSTALL_ANDROID_TOOLS" = "true" ]; then
    log "Adding Android tools to installation list..."
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL android-sdk-platform-tools-common adb fastboot"
fi

if [ "$INSTALL_DEV_TOOLS" = "true" ]; then
    log "Adding Dev tools to installation list..."
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL build-essential cmake gdb clang"
fi

if [ "$INSTALL_WINDOWS_TOOLS" = "true" ]; then
    log "Adding Windows cross-compilation tools to installation list..."
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL mingw-w64"
fi

if [ "$INSTALL_LINTER_TOOLS" = "true" ]; then
    log "Adding Linter tools to installation list..."
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL make"
fi

if [ -n "$ADDITIONAL_PACKAGES" ]; then
    log "Adding custom packages: $ADDITIONAL_PACKAGES"
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $ADDITIONAL_PACKAGES"
fi

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    log "Installing additional packages: $PACKAGES_TO_INSTALL"
    if apt-get update; then
        # shellcheck disable=SC2086
        if apt-get install -y $PACKAGES_TO_INSTALL; then
            log "Packages installed successfully."
        else
            log "Error: Failed to install some packages. Continuing anyway..."
        fi
        apt-get clean && rm -rf /var/lib/apt/lists/*
    else
        log "Error: apt-get update failed. Skipping package installation."
    fi
fi

if [ "$INSTALL_LINTER_TOOLS" = "true" ]; then
    log "Installing advanced linter tools..."
    (
        set +e
        curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
        python3 -m pip install poetry pre-commit --break-system-packages
    ) || log "Warning: Some linter tools failed to install."
fi

# Fix permissions carefully to avoid performance issues with large volume mounts
log "Ensuring correct permissions for essential directories..."
chown dev:dev /home/dev || log "Warning: chown /home/dev failed"
[ -d /home/dev/.vnc ] && chown -R dev:dev /home/dev/.vnc || log "Warning: chown .vnc failed"
[ -d /home/dev/.config ] && chown -R dev:dev /home/dev/.config || true

# Configure Docker Storage Driver
if [ ! -f /etc/docker/daemon.json ]; then
    log "Configuring Docker storage driver..."
    if command -v fuse-overlayfs >/dev/null 2>&1; then
        mkdir -p /etc/docker
        echo '{"storage-driver": "fuse-overlayfs"}' | tee /etc/docker/daemon.json > /dev/null
    fi
fi

# Start Docker Daemon
if [ -f /var/run/docker.pid ]; then
    rm -f /var/run/docker.pid
fi
log "Starting Docker service..."
service docker start || log "Warning: Failed to start Docker service."

# Wait for Docker (with timeout)
log "Waiting for Docker daemon to be ready..."
MAX_WAIT=30
WAIT_COUNT=0
while ! docker info >/dev/null 2>&1 && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 1
    ((WAIT_COUNT++))
done

if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
    log "Warning: Docker daemon did not start within $MAX_WAIT seconds."
else
    log "Docker is ready."
fi

# Desktop Environment Setup
log "Cleaning up old locks..."
rm -rf /tmp/.X*-lock /tmp/.X11-unix /home/dev/.config/google-chrome/SingletonLock

# VNC Password Logic
if [ -z "$VNC_PASSWORD" ]; then
    if [ -f /home/dev/.vnc/passwd_clear ]; then
        VNC_PASSWORD=$(cat /home/dev/.vnc/passwd_clear)
    else
        VNC_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
    fi
fi

if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /home/dev/.vnc
    echo "$VNC_PASSWORD" > /home/dev/.vnc/passwd_clear
    chmod 600 /home/dev/.vnc/passwd_clear
    chown dev:dev /home/dev/.vnc/passwd_clear

    echo "$VNC_PASSWORD" | vncpasswd -f > /home/dev/.vnc/passwd
    chmod 600 /home/dev/.vnc/passwd
    chown dev:dev /home/dev/.vnc/passwd

    echo "dev:$VNC_PASSWORD" | chpasswd
fi

export VNC_PASSWORD

# Ensure VNC startup script link
if [ ! -f /home/dev/.vnc/xstartup ]; then
    ln -s /usr/local/bin/vnc_startup.sh /home/dev/.vnc/xstartup
fi

# Start VNC Server as 'dev' user
log "Starting VNC Server..."
gosu dev vncserver :1 -geometry 1920x1080 -depth 24 -localhost no

# Start NoVNC Proxy
log "Starting NoVNC/Websockify..."
echo ""
echo "=============================================="
echo "  AntiGravity Desktop is ready!"
echo "  URL: http://localhost:6080/vnc.html"
if [ -n "$VNC_PASSWORD" ]; then
    echo "  Password: $VNC_PASSWORD"
fi
echo "=============================================="
echo ""

# Handover to websockify
exec gosu dev /usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080
