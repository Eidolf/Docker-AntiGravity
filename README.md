# Docker AntiGravity Linux Desktop

[![Release](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/release.yml/badge.svg)](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/release.yml)
[![CI Orchestrator](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/ci-orchestrator.yml/badge.svg)](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/ci-orchestrator.yml)

A lightweight, web-accessible Ubuntu desktop environment in a Docker container.
Features XFCE4, **Visual Studio Code**, Google Chrome, and a full Docker-in-Docker dev environment — accessible from any browser via NoVNC.

## Features

- **OS**: Ubuntu 24.04 LTS (Noble Numbat)
- **Desktop**: XFCE4 (lightweight and fast)
- **Remote Access**: NoVNC (browser-based) and TigerVNC direct
- **Tools**:
    - **Visual Studio Code**: Full IDE with 15+ pre-installed extensions (Python, Docker, GitLens, GitHub Copilot, and more)
    - **Google Antigravity v2.0**: Visual command center for multi-agent orchestration
    - **Browser**: Google Chrome Stable
    - **Text Editor**: Mousepad (lightweight plain-text editor outside of VS Code)
    - **Screenshots**: `xfce4-screenshooter` (GUI) + `scrot` (CLI)
    - **Git**: `git` CLI + `lazygit` terminal UI
    - **Docker**: Isolated Docker Daemon (Docker-in-Docker)
    - **Node.js**: v24.x
    - **Python**: 3.14
    - **Claude Code CLI**: Pre-installed for AI-assisted development
- **Persistence**: Home directory and settings persisted via Docker volume
- **First-Run Wizard**: Interactive GUI wizard on first login to select additional software (runs only once)

## First-Run Setup Wizard

On your **first login**, a setup wizard appears automatically before the desktop is ready to use.
It lets you select:

- **Additional system packages** — compilers (gcc, clang, cmake), Android tools, Windows cross-compilation (mingw-w64), Neovim, and more
- **Additional VS Code extensions** — Go, Rust, Java, Kubernetes, Terraform, Tailwind CSS, Jupyter, and more

The wizard runs **only once**. Your choices are saved to `~/.config/agy-setup-done`.  
It will **not** reappear on container restart or image update.

> **Headless / automated deployments**: If you are running without an interactive first login (e.g. CI, Portainer with no user session), use the environment variables below to pre-install packages instead.

## Environment Variables

These variables are evaluated at **every container start** (before the desktop session).  
They are the recommended approach for **automated or headless deployments** where the wizard is not accessible.

| Variable | Description |
|---|---|
| `VNC_PASSWORD` | Custom VNC/login password (auto-generated if omitted) |
| `ADDITIONAL_PACKAGES` | Space-separated list of extra apt packages (e.g. `htop nano default-jdk`) |
| `INSTALL_ANDROID_TOOLS` | `true` → installs `adb`, `fastboot`, platform tools |
| `INSTALL_DEV_TOOLS` | `true` → installs `build-essential`, `cmake`, `gdb`, `clang` |
| `INSTALL_LINTER_TOOLS` | `true` → installs `act`, `make`, `poetry`, `pre-commit` |
| `INSTALL_WINDOWS_TOOLS` | `true` → installs `mingw-w64` for Windows cross-compilation |

> **Tip**: For interactive use, leave these unset and configure everything via the first-run wizard instead.

## Login Credentials

- **Username**: `dev`
- **Password**: Auto-generated on first start (printed in container logs), or set via `VNC_PASSWORD`

```bash
# View the auto-generated password:
docker logs antigravity-desktop | grep "Password:"
```

## Getting Started

### Quick Start — Docker Compose / Portainer

```yaml
name: antigravity

services:
  antigravity-desktop:
    image: ghcr.io/eidolf/docker-antigravity:latest
    container_name: antigravity-desktop
    restart: unless-stopped
    ports:
      - "6080:6080"   # NoVNC web access
      # - "5901:5901" # Optional: VNC direct access
    shm_size: "2gb"   # Required for Chrome stability
    privileged: true  # Required for Docker-in-Docker
    environment:
      # Optional: set a fixed VNC password
      # - VNC_PASSWORD=mysecretpassword
      #
      # Optional: pre-install packages (alternative to the first-run wizard)
      # - ADDITIONAL_PACKAGES=htop nano default-jdk
      # - INSTALL_ANDROID_TOOLS=true
      # - INSTALL_DEV_TOOLS=true
      # - INSTALL_WINDOWS_TOOLS=true
    volumes:
      - antigravity-home:/home/dev
      - antigravity-workspace:/home/dev/workspace
      - antigravity-docker-data:/var/lib/docker

volumes:
  antigravity-home:
  antigravity-workspace:
  antigravity-docker-data:
```

1. Save as `docker-compose.yml` (or paste into Portainer Stack).
2. Run `docker compose up -d`.
3. Open [http://localhost:6080](http://localhost:6080) in your browser.
4. On first login: complete the setup wizard to select your tools.

### Docker CLI (Quick Run)

```bash
docker run -d \
  --name antigravity-desktop \
  -p 6080:6080 \
  --shm-size=2g \
  --privileged \
  ghcr.io/eidolf/docker-antigravity:latest
```

## VS Code Pre-installed Extensions

The following extensions are baked into the image at build time:

| Extension | Purpose |
|---|---|
| `ms-python.python` + `ms-python.vscode-pylance` | Python language support |
| `ms-vscode.cpptools` | C/C++ IntelliSense & debugging |
| `ms-vscode-remote.remote-containers` | Dev Containers |
| `ms-azuretools.vscode-docker` | Docker integration |
| `dbaeumer.vscode-eslint` | ESLint |
| `esbenp.prettier-vscode` | Prettier formatter |
| `eamodio.gitlens` + `mhutchie.git-graph` | Git tooling |
| `usernamehw.errorlens` | Inline error display |
| `streetsidesoftware.code-spell-checker` | Spell checker |
| `PKief.material-icon-theme` | File icons |
| `GitHub.copilot` + `GitHub.vscode-pull-request-github` | GitHub AI & PR integration |

Additional extensions can be selected via the first-run wizard or installed manually in VS Code.

## Nginx Reverse Proxy

If exposing via Nginx (e.g. port 443), configure WebSocket headers:

```nginx
server {
    listen 443 ssl;
    server_name desktop.example.com;

    # SSL config ...

    location / {
        proxy_pass http://localhost:6080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

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

### CI/CD Pipelines

- **Release** (`release.yml`): Triggers on push to `main` or release tags — builds and pushes the multi-arch image to `ghcr.io/eidolf/docker-antigravity`.
- **CI Orchestrator** (`ci-orchestrator.yml`): Runs on PRs and `main` pushes — Python linting (Ruff) and Dockerfile dry-run build.
- **PR Orchestrator** (`pr-orchestrator.yml`): Auto-labels PRs by changed files and size.

### Contributing

1. **Fork** the repository.
2. Create a **feature branch** (`git checkout -b feature/my-change`).
3. Commit your changes.
4. Push and open a **Pull Request** — CI checks run automatically.
