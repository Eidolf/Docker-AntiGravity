# Docker AntiGravity Linux Desktop

[![Docker Publish](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/eidolf/Docker-AntiGravity/actions/workflows/docker-publish.yml)
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

## Getting Started

### Using the Pre-built Image (Recommended)

This project publishes a production-ready image to GitHub Container Registry. You can run it directly using the provided `docker-compose.yml` or the CLI.

1. **Download `docker-compose.yml`** (or clone the repo):
   [Download docker-compose.yml](https://raw.githubusercontent.com/eidolf/Docker-AntiGravity/main/docker-compose.yml)

2. **Start the container**:
   ```bash
   docker-compose up -d
   ```

3. **Access the Desktop**:
   - **NoVNC (Web)**: [http://localhost:6080](http://localhost:6080)
   - **VNC Client**: `localhost:5901`
   - **Password**: `password` (default)
   - **User/Pass**: `dev` / `password`

### Using Docker CLI

```bash
docker run -d \
  --name antigravity \
  -p 6080:6080 \
  -p 5901:5901 \
  --shm-size=2g \
  ghcr.io/eidolf/docker-antigravity:latest
```

## Development & Workflows

This project follows modern DevOps practices with automated CI/CD pipelines.

### Workflows

- **Docker Publish** (`docker-publish.yml`):
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
