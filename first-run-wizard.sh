#!/bin/bash
# First-Run Setup Wizard for AntiGravity Desktop (VSCode Edition)
# This script runs ONCE after first login and lets the user select optional software.
# The selection is persisted to ~/.config/agy-setup-done so it never runs again.

WIZARD_DONE_FLAG="$HOME/.config/agy-setup-done"
WIZARD_LOG="$HOME/.config/agy-setup.log"

# If wizard already ran, exit immediately (safe against restarts/updates)
if [ -f "$WIZARD_DONE_FLAG" ]; then
    exit 0
fi

export DISPLAY="${DISPLAY:-:1}"
mkdir -p "$HOME/.config"

log_wizard() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$WIZARD_LOG"
}

log_wizard "Starting first-run setup wizard..."

# ─────────────────────────────────────────────
# Wait for a working X display (max 30s)
# ─────────────────────────────────────────────
for i in $(seq 1 30); do
    if xdpyinfo >/dev/null 2>&1; then break; fi
    sleep 1
done

# ─────────────────────────────────────────────
# Step 1: Welcome dialog
# ─────────────────────────────────────────────
zenity --info \
    --title="Welcome to AntiGravity Desktop" \
    --text="<b>Welcome! This is your first login.</b>\n\nThe setup wizard will help you install additional software.\nThis runs <b>only once</b> — your choices are saved permanently.\n\nClick OK to continue." \
    --width=480 \
    --ok-label="Let's go!" \
    2>/dev/null || true

# ─────────────────────────────────────────────
# Step 2: Optional software checklist
# ─────────────────────────────────────────────
CHOICES=$(zenity --list \
    --title="Optional Software Selection" \
    --text="<b>Select the optional software you want to install:</b>\n\nPre-installed (always available): VS Code, Chrome, Mousepad, Screenshot Tool, Docker-in-Docker, AntiGravity, Claude Code CLI" \
    --checklist \
    --column="Install" \
    --column="Package" \
    --column="Description" \
    FALSE "build-essential"      "C/C++ Compiler & build tools (gcc, g++, make)" \
    FALSE "cmake"                "CMake build system" \
    FALSE "gdb"                  "GNU Debugger" \
    FALSE "clang"                "Clang/LLVM compiler" \
    FALSE "mingw-w64"            "Windows cross-compilation toolchain" \
    FALSE "android-sdk-platform-tools-common" "Android Platform Tools (adb, fastboot)" \
    FALSE "git-lfs"              "Git Large File Storage" \
    FALSE "neovim"               "Neovim (terminal text editor)" \
    FALSE "htop"                 "Interactive process viewer" \
    FALSE "tree"                 "Directory tree viewer" \
    FALSE "unzip"                "Unzip utility" \
    FALSE "rsync"                "Fast file synchronization" \
    FALSE "make"                 "Make build utility" \
    FALSE "pre-commit"           "Pre-commit hook framework (via pip)" \
    FALSE "poetry"               "Python dependency manager (via pip)" \
    --separator="|" \
    --width=680 \
    --height=520 \
    2>/dev/null) || CHOICES=""

# ─────────────────────────────────────────────
# Step 3: VS Code extra extensions
# ─────────────────────────────────────────────
VSCODE_CHOICES=$(zenity --list \
    --title="VS Code Extra Extensions" \
    --text="<b>Select additional VS Code extensions to install:</b>\n\nAlready installed: Python, Pylance, C/C++, Docker, ESLint, Prettier, GitLens, Git Graph, Error Lens, Spell Checker, Material Icons, GitHub Copilot, GitHub PRs" \
    --checklist \
    --column="Install" \
    --column="Extension ID" \
    --column="Description" \
    FALSE "ms-vscode.live-server"            "Live Server (local dev server)" \
    FALSE "ms-dotnettools.csharp"            "C# / .NET support" \
    FALSE "golang.go"                        "Go language support" \
    FALSE "rust-lang.rust-analyzer"          "Rust language support" \
    FALSE "redhat.java"                      "Java support (Red Hat)" \
    FALSE "vscjava.vscode-java-pack"         "Java Extension Pack" \
    FALSE "ms-kubernetes-tools.vscode-kubernetes-tools" "Kubernetes support" \
    FALSE "hashicorp.terraform"              "Terraform / HCL support" \
    FALSE "dbaeumer.vscode-eslint"           "ESLint (extra)" \
    FALSE "bradlc.vscode-tailwindcss"        "Tailwind CSS IntelliSense" \
    FALSE "formulahendry.code-runner"        "Code Runner" \
    FALSE "ms-vscode.hexeditor"             "Hex Editor" \
    FALSE "charliermarsh.ruff"              "Ruff Python Linter" \
    FALSE "ms-toolsai.jupyter"              "Jupyter Notebooks" \
    --separator="|" \
    --width=720 \
    --height=540 \
    2>/dev/null) || VSCODE_CHOICES=""

# ─────────────────────────────────────────────
# Step 4: Confirm and install
# ─────────────────────────────────────────────
SUMMARY="<b>Your selections:</b>\n\n"
if [ -n "$CHOICES" ]; then
    SUMMARY+="<b>System packages:</b>\n$(echo "$CHOICES" | tr '|' '\n' | sed 's/^/  • /')\n\n"
else
    SUMMARY+="<b>System packages:</b> None\n\n"
fi
if [ -n "$VSCODE_CHOICES" ]; then
    SUMMARY+="<b>VS Code extensions:</b>\n$(echo "$VSCODE_CHOICES" | tr '|' '\n' | sed 's/^/  • /')\n"
else
    SUMMARY+="<b>VS Code extensions:</b> None\n"
fi

zenity --question \
    --title="Confirm Installation" \
    --text="$SUMMARY\n\nProceed with installation?" \
    --ok-label="Install" \
    --cancel-label="Skip All" \
    --width=500 \
    2>/dev/null
CONFIRM_RC=$?

if [ $CONFIRM_RC -eq 0 ]; then
    # ── Install system packages ──────────────────
    if [ -n "$CHOICES" ]; then
        # Extract pip packages before apt install
        PIP_PACKAGES=""
        APT_PACKAGES=""
        while IFS='|' read -ra items; do
            for item in "${items[@]}"; do
                case "$item" in
                    "pre-commit"|"poetry") PIP_PACKAGES="$PIP_PACKAGES $item" ;;
                    *) APT_PACKAGES="$APT_PACKAGES $item" ;;
                esac
            done
        done <<< "$CHOICES"

        if [ -n "$APT_PACKAGES" ]; then
            log_wizard "Installing APT packages:$APT_PACKAGES"
            (
                sudo apt-get update
                # shellcheck disable=SC2086
                sudo apt-get install -y $APT_PACKAGES
                sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*
            ) 2>&1 | tee -a "$WIZARD_LOG" | \
            zenity --progress \
                --title="Installing packages..." \
                --text="Installing system packages, please wait..." \
                --pulsate --auto-close --no-cancel \
                --width=400 2>/dev/null || true
        fi

        if [ -n "$PIP_PACKAGES" ]; then
            log_wizard "Installing pip packages:$PIP_PACKAGES"
            # shellcheck disable=SC2086
            python3 -m pip install $PIP_PACKAGES --break-system-packages 2>&1 | tee -a "$WIZARD_LOG" || true
        fi
    fi

    # ── Install VS Code extensions ───────────────
    if [ -n "$VSCODE_CHOICES" ]; then
        log_wizard "Installing VS Code extensions: $VSCODE_CHOICES"
        while IFS='|' read -ra exts; do
            for ext in "${exts[@]}"; do
                log_wizard "  Installing extension: $ext"
                code --no-sandbox --install-extension "$ext" 2>&1 | tee -a "$WIZARD_LOG" || true
            done
        done <<< "$VSCODE_CHOICES"
    fi

    zenity --info \
        --title="Setup Complete" \
        --text="<b>Installation complete!</b>\n\nYour selections have been saved.\nThis wizard will not appear again.\n\nEnjoy AntiGravity Desktop!" \
        --width=400 \
        2>/dev/null || true
else
    log_wizard "User skipped all optional installations."
fi

# ─────────────────────────────────────────────
# Mark wizard as done — NEVER run again
# ─────────────────────────────────────────────
date --iso-8601=seconds > "$WIZARD_DONE_FLAG"
log_wizard "Wizard completed. Flag written to $WIZARD_DONE_FLAG"

