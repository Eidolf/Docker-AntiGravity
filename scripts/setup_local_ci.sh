#!/bin/bash
set -e

# Pre-Flight Setup Script for Docker-AntiGravity

echo "=== Environment Audit ==="

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found."
    echo "   Please install Docker: https://docs.docker.com/engine/install/"
    exit 1
else
    echo "✅ Docker is installed."
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon not running."
    echo "   Please start Docker Desktop or the docker service."
    exit 1
else
    echo "✅ Docker daemon is running."
fi

# Check for act
if ! command -v act &> /dev/null; then
    echo "⚠️  'act' not found."
    echo "   Installing act to /usr/local/bin (requires sudo)..."
    curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
else
    echo "✅ act is installed."
fi

# Check for Ruff (Python linter)
if ! command -v ruff &> /dev/null; then
    echo "⚠️  'ruff' not found."
    echo "   Installing ruff..."
    pip install ruff
else
    echo "✅ ruff is installed."
fi

# Check for Git
if ! command -v git &> /dev/null; then
    echo "❌ Git not found."
    exit 1
else
    echo "✅ Git is installed."
fi

echo ""
echo "=== Setup Complete ==="
echo "You are ready to run './scripts/preflight.sh'"
