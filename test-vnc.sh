#!/bin/bash
VNC_PASSWORD=secret
mkdir -p /home/dev/.vnc
echo "$VNC_PASSWORD" | vncpasswd -f > /home/dev/.vnc/passwd
chmod 600 /home/dev/.vnc/passwd
chown -R dev:dev /home/dev/.vnc
echo "dev:$VNC_PASSWORD" | chpasswd
su - dev -c "vncserver :2 -geometry 1920x1080 -depth 24 -localhost no > /tmp/vnc.log 2>&1"
cat /tmp/vnc.log
