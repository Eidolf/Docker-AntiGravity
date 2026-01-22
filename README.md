# Docker AntiGravity Linux Desktop

[![Release](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/release.yml/badge.svg)](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/release.yml)
[![CI Orchestrator](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/ci-orchestrator.yml/badge.svg)](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/ci-orchestrator.yml)

A lightweight, web-accessible Ubuntu desktop environment in a Docker container.
It features XFCE4, Google Chrome, and standard Git tools, accessible via your browser using NoVNC.

## Features
- **OS**: Ubuntu 22.04 LTS (Jammy Jellyfish).
- **Desktop**: XFCE4 (Lightweight and fast).
- **Remote Access**: NoVNC (Browser-based) and TigerVNC.
- **Tools**:
    - **Browser**: Google Chrome Stable.
    - **Git**: Built-in CLI `git`.
    - **Git GUI**: `git-gui` (Simple, native graphical interface).
    - **LazyGit**: Terminal-based UI for git (run `lazygit` in terminal).
    - **Docker**: Isolated Docker Daemon (Docker-in-Docker). Creates its own containers, separate from host.
    - **Node.js**: LTS version (v22.x).
    - **Python**: Version 3.13.
- **Persistence**: User settings and home directory are persisted via Docker volume.

## Dynamic Package Installation
You can install additional packages at startup using environment variables:

| Variable | Description |
|----------|-------------|
| `ADDITIONAL_PACKAGES` | Space-separated list of apt packages to install (e.g., `htop nano`) |
| `INSTALL_ANDROID_TOOLS` | Set to `true` to install `adb`, `fastboot`, and platform tools |
| `INSTALL_DEV_TOOLS` | Set to `true` to install `build-essential`, `cmake`, `gdb`, `clang` |
| `INSTALL_WINDOWS_TOOLS` | Set to `true` to install `mingw-w64` for cross-compilation |

## Getting Started

### Quick Start with Portainer / Docker Compose

You can easily deploy this stack using Portainer or Docker Compose. Copy the configuration below:

```yaml
version: '3.8'
services:
  antigravity:
    image: ghcr.io/eidolf/docker-antigravity:latest
    container_name: antigravity
    restart: unless-stopped
    ports:
      - "6080:6080" # Web Access (NoVNC)
      # - "5901:5901" # Optional: VNC Direct Access
    environment:
      - PUID=1000 # User ID
      - PGID=1000 # Group ID
      # Dynamic Package Installation Examples:
      # - ADDITIONAL_PACKAGES=htop nano default-jdk
      # - INSTALL_ANDROID_TOOLS=true
      # - INSTALL_DEV_TOOLS=true
      # - INSTALL_WINDOWS_TOOLS=true
    volumes:
      # Persist user home directory (settings, files)
      - antigravity-data:/home/dev
      # Optional: Mount a local workspace
      # - /path/to/local/workspace:/home/dev/workspace
    shm_size: "2gb"    # Required for Chrome to prevent crashes
    privileged: true   # Required for Docker-in-Docker functionality

volumes:
  antigravity-data:
```

1. Copy the YAML above into your **Portainer Stack** or save as `docker-compose.yml`.
2. Adjust ports or volumes if necessary.
3. Deploy the stack.
4. Access via [http://localhost:6080](http://localhost:6080).

### Using the Pre-built Image (CLI)

### Using Docker CLI

```bash
docker run -d \
  --name antigravity \
  -p 6080:6080 \
  -p 5901:5901 \
  --shm-size=2g \
  ghcr.io/eidolf/docker-antigravity:latest
```

### Nginx Reverse Proxy Configuration

If you are running behind Nginx (e.g., exposing port 443), you must configure WebSocket headers to avoid `404 Not Found` errors.

Example `nginx` configuration block:

```nginx
server {
    listen 443 ssl;
    server_name desktop.example.com;

    # SSL Certs ...
    # ...

    location / {
        proxy_pass http://localhost:6080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        # Crucial for NoVNC to find web resources:
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Redirect Websockify traffic if needed (though root / usually handles it if Upgrade headers are set)
    location /websockify {
        proxy_pass http://localhost:6080/websockify;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
}
```

## Development & Workflows

This project follows modern DevOps practices with automated CI/CD pipelines.

### Workflows

- **Release** (`release.yml`):
  - Triggers on push to `main` or release tags.
  - Builds the Docker image.
  - Pushes to `ghcr.io/eidolf/docker-antigravity`.
  - Tags images with `latest`, branch name, and semantic version.

- **CI Orchestrator** (`ci-orchestrator.yml`):
  - Triggers on Pull Requests and pushes to `main`.
  - Runs Python Linting (Ruff).
  - Performs a "Dry Run" Docker build to ensure the Dockerfile is valid.
  - Cancels outdated runs automatically to save resources.

- **PR Orchestrator** (`pr-orchestrator.yml`):
  - Automatically labels PRs based on changed files (e.g., `docker`, `ci`, `docs`).
  - Adds a size label (e.g., `size/XS`, `size/L`) to indicate PR complexity.

### Contributing

1. **Fork** the repository.
2. Create a **Feature Branch** (`git checkout -b feature/NewThing`).
3. **Commit** your changes.
4. **Push** to the branch.
5. Open a **Pull Request**. The templates will guide you.

Please ensure your code passes the **CI Orchestrator** checks before merging.
