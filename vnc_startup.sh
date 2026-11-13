#!/bin/bash
# VNC xstartup — AntiGravity Desktop (VSCode Edition)

export DISPLAY=:1
export XAUTHORITY=$HOME/.Xauthority
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start DBus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Start gnome-keyring-daemon
if [ -n "$VNC_PASSWORD" ]; then
    echo -n "$VNC_PASSWORD" | gnome-keyring-daemon --login
    eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
else
    eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
fi
export SSH_AUTH_SOCK

# Create autostart directory
mkdir -p $HOME/.config/autostart

# Ensure persistent data directory
sudo mkdir -p /data/antigravity
sudo chown -R dev:dev /data/antigravity

# Configure VS Code to run without sandbox (required inside Docker)
mkdir -p $HOME/.config/Code/User
VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
if [ ! -f "$VSCODE_SETTINGS" ]; then
    cat > "$VSCODE_SETTINGS" << 'EOF'
{
    "telemetry.telemetryLevel": "off",
    "editor.fontFamily": "'JetBrains Mono', 'Cascadia Code', 'Fira Code', monospace",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "editor.formatOnSave": true,
    "editor.minimap.enabled": true,
    "editor.rulers": [80, 120],
    "editor.wordWrap": "off",
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "workbench.iconTheme": "material-icon-theme",
    "workbench.colorTheme": "Default Dark Modern",
    "terminal.integrated.defaultProfile.linux": "bash",
    "git.enableSmartCommit": true,
    "git.autofetch": true,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "extensions.autoUpdate": false,
    "security.workspace.trust.enabled": false,
    "docker.enableDockerComposeLanguageService": true
}
EOF
fi

# Autostart the first-run wizard (runs only once, guarded by flag file)
if [ ! -f "$HOME/.config/agy-setup-done" ]; then
    # Launch wizard shortly after desktop loads
    (sleep 4 && /usr/local/bin/first-run-wizard.sh) &
fi

# Start XFCE4 Desktop Environment
startxfce4
