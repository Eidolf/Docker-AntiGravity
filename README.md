# Docker AntiGravity Linux Desktop

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
16:     - **Docker**: Docker CLI & Compose (uses host Docker daemon).

## Prerequisites
- [Docker](https://docs.docker.com/get-docker/) installed.
- [Docker Compose](https://docs.docker.com/compose/install/) installed.

## Installation & Usage

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/Docker-AntiGravity.git
   cd Docker-AntiGravity
   ```

2. **Build and Start the Container:**
   ```bash
   docker-compose up -d --build
   ```

3. **Access the Desktop:**
   Open your web browser and navigate to:
   [http://localhost:6080](http://localhost:6080)

   *Note: If asked for a password, the default password for both VNC and the `dev` user is `password`.*

4. **Stop the Container:**
   ```bash
   docker-compose down
   ```

## Development Workflow

### Using Git
You can use Git directly inside the desktop terminal.
- **Terminal UI**: Type `lazygit` in the terminal for an interactive git interface.
- **Graphical UI**: Open "Git GUI" from the application menu or type `git citool`.

### Persistent Data
The `/home/dev/workspace` directory inside the container is persisted to the `workspace` docker volume. Save your work there.

## Troubleshooting

- **Chrome Crashes**: Ensure `shm_size: "2gb"` is set in `docker-compose.yml`. Chrome requires shared memory.
- **Port Conflicts**: If port 6080 is in use, change the mapping in `docker-compose.yml` (e.g., `"8080:6080"`).
- **VNC Connection Issues**: Check container logs with `docker-compose logs -f`.

## License
MIT License
