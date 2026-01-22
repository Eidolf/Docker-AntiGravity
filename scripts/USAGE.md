# Pre-Flight Validation System Usage

This system allows you to run GitHub Actions workflows locally to verify your code before pushing.

## Setup

1.  Run the setup script to ensure you have all necessary tools:
    ```bash
    ./scripts/setup_local_ci.sh
    ```

    This will check for:
    - Docker (Daemon must be running)
    - `act` (GitHub Actions local runner)
    - `ruff` (Python linter)

## Running Checks

To run the pre-flight checks, execute:

```bash
./scripts/preflight.sh
```

This script will:
1.  Run `ruff` locally for immediate Python feedback.
2.  Use `act` to run the `lint` job defined in `.github/workflows/ci-orchestrator.yml`.
3.  Use `act` to run the `build-check` job (dry-run Docker build).

## Troubleshooting

-   **Docker Socket:** Ensure you have permissions to access `/var/run/docker.sock` (usually by being in the `docker` group).
-   **Act Images:** On first run, `act` might ask you to select a micro/medium/large image. 'Medium' is usually a good balance.
-   **Secrets:** If workflows require secrets, create a `.secrets` file in the root and pass it to act if you modify the script (though the current CI doesn't strictly need it for lint/build).
