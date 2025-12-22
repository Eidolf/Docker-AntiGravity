#!/bin/bash

# Configuration
min_web_port=6080
min_vnc_port=5901
max_retries=10

check_port() {
    (echo >/dev/tcp/localhost/$1) &>/dev/null
    if [ $? -eq 0 ]; then
        return 1 # Port is in use
    else
        return 0 # Port is free
    fi
}

find_available_port() {
    local port=$1
    local count=0
    while ! check_port $port; do
        if [ $count -ge $max_retries ]; then
            echo "Error: Could not find available port starting from $1 after $max_retries attempts." >&2
            return 1
        fi
        echo "Port $port is in use, trying next..." >&2
        port=$((port + 1))
        count=$((count + 1))
    done
    echo $port
}

echo "Checking for available ports..."

HOST_WEB_PORT=$(find_available_port $min_web_port)
if [ $? -ne 0 ]; then exit 1; fi

HOST_VNC_PORT=$(find_available_port $min_vnc_port)
if [ $? -ne 0 ]; then exit 1; fi

echo "-----------------------------------------------------"
echo "  Found available ports:"
echo "    Web Interface: http://localhost:$HOST_WEB_PORT"
echo "    VNC Direct:    localhost:$HOST_VNC_PORT"
echo "-----------------------------------------------------"

export HOST_WEB_PORT
export HOST_VNC_PORT

echo "Starting AntiGravity..."
docker compose up -d

echo ""
echo "Waiting for container to generate password..."
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker logs antigravity-desktop 2>&1 | grep -q "GENERATED PASSPHRASE"; then
        echo ""
        echo "====================================================="
        docker logs antigravity-desktop 2>&1 | grep -A 2 "GENERATED PASSPHRASE:"
        echo "====================================================="
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $elapsed -ge $timeout ]; then
    echo "Timed out waiting for password. Please check logs manually: docker logs antigravity-desktop"
fi

echo ""
echo "Access via: http://localhost:$HOST_WEB_PORT/vnc.html"
echo ""
echo "To stop the application, run: docker compose down"
