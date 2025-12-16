#!/bin/bash
set -e

# Mask WSL detection
if [ -f /etc/fake_version ]; then
    sudo mount --bind /etc/fake_version /proc/version
fi
if [ -f /etc/fake_osrelease ]; then
    sudo mount --bind /etc/fake_osrelease /proc/sys/kernel/osrelease
fi

# Remove any existing VNC locks
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

# Starte VNC Server
echo "Starting VNC Server..."
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no

# Starte NoVNC Proxy
echo "Starting NoVNC..."
# Pointing websockify to the VNC server port 5901
/usr/share/novnc/utils/launch.sh --vnc localhost:5901 --listen 6080
