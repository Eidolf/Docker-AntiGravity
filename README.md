# Docker AntiGravity Linux Desktop

[![Release](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/release.yml/badge.svg)](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/release.yml)
[![CI Orchestrator](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/ci-orchestrator.yml/badge.svg)](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/ci-orchestrator.yml)

A lightweight, web-accessible Ubuntu desktop environment in a Docker container.
Features XFCE4, **Visual Studio Code**, Google Chrome, and a full Docker-in-Docker dev environment — accessible from any browser via NoVNC.

## Project ecosystem

- [Agent instructions](AGENTS.md)
- [Project profile](https://github.com/Eidolf/ER-KnowledgeBase/blob/main/Projects/Docker-AntiGravity/README.md) (private)
- [Knowledge-Platform](https://github.com/Eidolf/Knowledge-Platform)

## Features

- **OS**: Ubuntu 24.04 LTS (Noble Numbat)
- **Desktop**: XFCE4 (lightweight and fast)
- **Remote Access**: NoVNC (browser-based) and TigerVNC direct
- **Tools**:
    - **Visual Studio Code**: Full IDE with 15+ pre-installed extensions (Python, Docker, GitLens, built-in GitHub Copilot Chat, and more)
    - **Google Antigravity v2.0**: Visual command center for multi-agent orchestration
    - **Browser**: Google Chrome Stable
    - **Text Editor**: Mousepad (lightweight plain-text editor outside of VS Code)
    - **Screenshots**: `xfce4-screenshooter` (GUI) + `scrot` (CLI)
    - **Git**: `git` CLI + `lazygit` terminal UI + GitHub CLI (`gh`)
    - **Docker**: Isolated Docker Daemon (Docker-in-Docker)
    - **Node.js**: v24.x
    - **Python**: 3.14
    - **Claude Code CLI**: Pre-installed for AI-assisted development
- **Persistence**: Home directory and settings persisted via Docker volume
- **First-Run Wizard**: Interactive GUI wizard on first login to select additional
  software; completion is recorded after success or an explicit skip

## First-Run Setup Wizard

On your **first login**, a setup wizard appears automatically before the desktop is ready to use.
It lets you select:

- **Additional system packages** — compilers (gcc, clang, cmake), Android tools, Windows cross-compilation (mingw-w64), Neovim, and more
- **Additional VS Code extensions** — Go, Rust, Java, Kubernetes, Terraform, Tailwind CSS, Jupyter, and more

After a successful installation or an explicit **Skip All**, the wizard records
completion in `~/.config/agy-setup-done` and does not reappear. If an installation
fails, it reports the error and remains retryable; review
`~/.config/agy-setup.log`, then restart the desktop or run
`/usr/local/bin/first-run-wizard.sh`.

Packages installed by the wizard are stored in the container filesystem, not the
home volume. They are lost when the container is recreated, while the completion
flag remains in the home volume. For packages that must survive image updates,
use `ADDITIONAL_PACKAGES`, the package-group environment variables, or a derived
image. Image-baked VS Code extensions are copied into the persistent profile
without overwriting existing extensions at startup; wizard-installed extensions
continue to live in the persisted home volume.

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

> **Tip**: Use the first-run wizard for interactive, container-local package installs. Use the environment variables or a derived image for packages that must survive container recreation.

## Application Updates

At each XFCE desktop start, **Software Updates** checks the configured APT
repositories in the background after a short delay. It never installs updates
automatically or blocks the desktop from starting. If updates are available, a
package-selection window appears with nothing selected by default. Choose the
packages you want, save your work, and close the affected applications. A
terminal then shows APT's proposed changes and asks for confirmation before
installing; package removal is disabled. Reopen updated applications afterwards.
This reduces disruption but cannot guarantee that an upstream update is bug-free.

You can also open **Software Updates** from the applications menu at any time,
or run `software-updates` in the desktop terminal. For a terminal-only check
without installation, run `software-updates --check`. Network/repository errors
are reported rather than treating stale package lists as a successful check.
Check logs are stored in `~/.cache/agy-updates/updates.log`; installation output
is stored separately in `~/.cache/agy-updates/install.log`.

This checks **APT-managed packages only**, including VS Code and the browser
when their repositories are configured. It does not update Antigravity's
standalone archive, VS Code extensions, Claude Code, or other tools installed
outside APT. Antigravity has its separate **Update Antigravity** launcher.

For Portainer, no extra environment variable is required: deploy an image
containing this feature and keep the existing volumes. Updates installed inside
the container survive stopping/starting that same container, but **not container
recreation**. The home volume preserves settings, not system packages. For
reproducible versions across redeployments, update/rebuild the image instead.
There is no automatic rollback of installed packages.

To disable the startup check for your persisted user profile, open XFCE
**Session and Startup → Application Autostart** and disable **Software Update
Check**. Manual checks remain available.

## GitHub CLI and Git Authentication

The image includes the official GitHub CLI (`gh`). Authenticate as the `dev` user
from a terminal in the desktop:

The CLI is installed when the image is built. Rebuild the image and recreate
the container to make it available in an existing deployment; no credentials
are baked into the image.

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Follow the URL and one-time code shown by the CLI in a browser, then authorize
the GitHub CLI. Once login succeeds, configure Git to use `gh` for HTTPS
credentials and verify the session:

```bash
gh auth setup-git
gh auth status
git ls-remote https://github.com/OWNER/REPOSITORY.git
```

The GitHub account must already have access to any private repository. The
container persists `/home/dev`; treat that volume as sensitive because GitHub
CLI credentials may be stored there. Never put tokens in the Dockerfile,
Compose file, environment variables, or repository.

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
    name: antigravity-home
  antigravity-workspace:
    name: antigravity-workspace
  antigravity-docker-data:
    name: antigravity-docker-data
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

The following extensions are baked into the image at build time under
`/opt/antigravity-extensions`, outside the persisted `/home/dev` volume. At
startup, missing image-baked extensions are copied into the VS Code profile, so
they remain available when an existing home volume is reused without replacing
extensions already installed there.

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
| VS Code built-in Copilot Chat + `GitHub.vscode-pull-request-github` | GitHub AI & PR integration |

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

- **Release** (`release.yml`): Manually started from the GitHub Actions **Release Manager** workflow on `main`; select `nightly` or `stable` to build and push the multi-arch image to `ghcr.io/eidolf/docker-antigravity`. CalVer uses `YYYY.M.PATCH`; Stable Git tags are the version source of truth. Historical unprefixed stable tags are recognized, and all new Git tags use `v` (for example, `v2026.11.3`). `VERSION` mirrors Stable only; Nightlies use the next Stable candidate with a unique UTC `YYYYMMDD.HHMM.<run-id>.<attempt>` suffix and do not write or commit `VERSION`. Container tags omit `v`; only Stable updates the container `latest` tag and GitHub's latest-release designation.
- **Rollback** (`rollback.yml`): Restores the mutable `latest` container alias to an existing Stable release. It does not delete or rewrite Git tags, GitHub releases, container version tags, or release history.
- **CI Orchestrator** (`ci-orchestrator.yml`): Runs on PRs and `main` pushes — Python linting (Ruff) and Dockerfile dry-run build.
- **PR Orchestrator** (`pr-orchestrator.yml`): Auto-labels PRs by changed files and size.

### Contributing

1. **Fork** the repository.
2. Create a **feature branch** (`git checkout -b feature/my-change`).
3. Commit your changes.
4. Push and open a **Pull Request** — CI checks run automatically.
