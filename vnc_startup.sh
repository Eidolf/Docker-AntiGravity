#!/bin/bash
# This file is typically used by ~/.vnc/xstartup, but we'll configure it via the Dockerfile or implicitly by vncserver if needed.
# For TigerVNC, the default xstartup usually works or we can define it.

# Ensure this is used as the xstartup
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
startxfce4 &
