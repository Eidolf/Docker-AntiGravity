#!/bin/bash
# This file is typically used by ~/.vnc/xstartup, but we'll configure it via the Dockerfile or implicitly by vncserver if needed.
# For TigerVNC, the default xstartup usually works or we can define it.

# Ensure this is used as the xstartup
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start DBus if it's not running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Start gnome-keyring-daemon
# We need to unlock the keyring. Since we don't have the password in plain text easily accessible
# (unless we reuse VNC_PASSWORD or just leave it locked but available), we start the daemon.
# For many apps, just having the daemon running and the socket available clears the "keyring not available" warning.
# If VNC_PASSWORD is set, we try to unlock the login keyring with it.
if [ -n "$VNC_PASSWORD" ]; then
    echo -n "$VNC_PASSWORD" | gnome-keyring-daemon --login
    eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
else
    eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
fi
export SSH_AUTH_SOCK

# Create Autostart directory
mkdir -p $HOME/.config/autostart

# Ensure persistent data directory exists and is writable
sudo mkdir -p /data/antigravity
sudo chown -R dev:dev /data/antigravity

# Create Antigravity Autostart entry
cat > $HOME/.config/autostart/antigravity.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Antigravity
Exec=antigravity --start-maximized --start-fullscreen --no-sandbox --user-data-dir=/data/antigravity
StartupNotify=false
Terminal=false
Hidden=false
EOF

# Background task to force Antigravity into fullscreen
# It waits for the window to appear and then sets the fullscreen property
(
    echo "Waiting for Antigravity window..."
    for i in {1..30}; do
        if wmctrl -l | grep -i "Antigravity"; then
            echo "Antigravity window found. Forcing fullscreen..."
            sleep 1 # Wait for window to be fully ready
            wmctrl -r ":ACTIVE:" -b add,fullscreen || wmctrl -r "Antigravity" -b add,fullscreen
            break
        fi
        sleep 1
    done
) &



startxfce4
