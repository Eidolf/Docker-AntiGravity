#!/bin/bash

# Pre-Flight Validation Script
# Runs local linters and GitHub Actions simulations via act

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

echo -e "${YELLOW}=== 🚀 Starting Pre-Flight Checks ===${NC}"

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

echo -e "\n${YELLOW}▶ Running GitHub Actions Workflow (Lint Job)...${NC}"
# Run specific job 'lint' from CI workflow
if act -j lint --rm; then
    echo -e "${GREEN}✔ CI Lint Job Passed${NC}"
else
    echo -e "${RED}✘ CI Lint Job Failed${NC}"
    FAILED=1
fi

echo -e "\n${YELLOW}▶ Running GitHub Actions Workflow (Build Check)...${NC}"
# Run specific job 'build-check' from CI workflow
# Note: This might take longer as it builds the Docker image
if act -j build-check --rm; then
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
