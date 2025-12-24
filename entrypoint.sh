#!/bin/bash
set -e

# Mask WSL detection
if [ -f /etc/fake_version ]; then
    sudo mount --bind /etc/fake_version /proc/version
fi
if [ -f /etc/fake_osrelease ]; then
    sudo mount --bind /etc/fake_osrelease /proc/sys/kernel/osrelease
fi

# Start Docker Daemon
if [ -f /var/run/docker.pid ]; then
    rm /var/run/docker.pid
fi
sudo service docker start
echo "Waiting for Docker to start..."
while ! sudo docker info >/dev/null 2>&1; do
    sleep 1
done
echo "Docker started."

# Remove any existing VNC locks
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

# Generate random passphrase if VNC_PASSWORD not set
if [ -z "$VNC_PASSWORD" ]; then
    if [ -f /home/dev/.vnc/passwd ]; then
        echo "Example: Persistent password found. Skipping generation."
    else
        VNC_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)
    fi
fi

# Set VNC password if VNC_PASSWORD is set (either from env or generated)
if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /home/dev/.vnc
    echo "$VNC_PASSWORD" | vncpasswd -f > /home/dev/.vnc/passwd
    chmod 600 /home/dev/.vnc/passwd
    chown dev:dev /home/dev/.vnc/passwd

    # Set user password (for sudo/ssh if needed)
    echo "dev:$VNC_PASSWORD" | sudo chpasswd
fi

# Start VNC Server
echo "Starting VNC Server..."
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no

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
/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080
