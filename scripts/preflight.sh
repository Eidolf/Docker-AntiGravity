#!/bin/bash

# Pre-Flight Validation Script
# Runs local linters and GitHub Actions simulations via act

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

echo -e "${YELLOW}=== 🚀 Starting Pre-Flight Checks ===${NC}"

# Ensure we are in the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

if [ -z "$PROJECT_ROOT" ]; then
    echo -e "${RED}❌ Could not determine project root. Are you in a git repository?${NC}"
    exit 1
fi

cd "$PROJECT_ROOT"
echo -e "${YELLOW}📂 Working in: $PROJECT_ROOT${NC}"

# 1. Local Python Linting (Fast)
echo -e "\n${YELLOW}▶ Running Local Python Lint (Ruff)...${NC}"
if command -v ruff &> /dev/null; then
    if ruff check .; then
        echo -e "${GREEN}✔ Local Lint Passed${NC}"
    else
        echo -e "${RED}✘ Local Lint Failed${NC}"
        FAILED=1
    fi
else
    echo -e "${YELLOW}⚠ Ruff not found locally, skipping fast lint (will run in Docker).${NC}"
fi

# 2. GitHub Actions Simulation (Act)
# We need to handle the case where act asks to choose an image on first run.
# We'll use the default medium image or non-interactive if configured.

echo -e "\n${YELLOW}▶ Running GitHub Actions Workflow (Python Lint Job)...${NC}"
# Run specific job 'lint-python' from CI workflow
if act -j lint-python --rm; then
    echo -e "${GREEN}✔ CI Python Lint Job Passed${NC}"
else
    echo -e "${RED}✘ CI Python Lint Job Failed${NC}"
    FAILED=1
fi

echo -e "\n${YELLOW}▶ Running GitHub Actions Workflow (Build Check)...${NC}"
# Run specific job 'build-validation' from CI workflow
# Note: This might take longer as it builds the Docker image
# Fix: Pass the host docker group ID to the container so it can access the socket
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
if act -j build-validation --rm --container-options "--group-add $DOCKER_GID"; then
    echo -e "${GREEN}✔ CI Build Check Job Passed${NC}"
else
    echo -e "${RED}✘ CI Build Check Job Failed${NC}"
    FAILED=1
fi

echo -e "\n${YELLOW}=== 📊 Pre-Flight Summary ===${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All Checks Passed! You are safe to push.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Please review the output above.${NC}"
    exit 1
fi
