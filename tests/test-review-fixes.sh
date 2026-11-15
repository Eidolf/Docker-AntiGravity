#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

source "$ROOT_DIR/scripts/antigravity-version.sh"

validate_antigravity_hub_values 2.1.4 6481382726303744
if validate_antigravity_hub_values '2.1.4/../../tmp' 6481382726303744 ||
    validate_antigravity_hub_values 2.1.4 '6481382726303744|bad' ||
    validate_antigravity_hub_values 2.1.4 0; then
    echo "Invalid Antigravity version values were accepted." >&2
    exit 1
fi

read_manual_antigravity_hub_values 2>"$TEMP_DIR/manual-validation.log" <<'EOF'
not-a-version
2.2.0
12x
1234567890123456
EOF
[[ "$HUB_VER" == "2.2.0" && "$HUB_BUILD" == "1234567890123456" ]]
grep -q "Invalid version" "$TEMP_DIR/manual-validation.log"
grep -q "Invalid build ID" "$TEMP_DIR/manual-validation.log"

mkdir -p "$TEMP_DIR/bin"
cat > "$TEMP_DIR/bin/xdpyinfo" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$TEMP_DIR/bin/zenity" <<'EOF'
#!/bin/bash
case "$*" in
    *"--list"*)
        if [[ "$*" == *"Optional Software Selection"* ]]; then
            printf '%s' "${WIZARD_PACKAGE_CHOICES:-}"
        else
            printf '%s' "${WIZARD_EXTENSION_CHOICES:-}"
        fi
        ;;
    *"--question"*) exit "${WIZARD_CONFIRM_RC:-0}" ;;
    *"--progress"*) cat >/dev/null ;;
    *) exit 0 ;;
esac
EOF
cat > "$TEMP_DIR/bin/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${WIZARD_SUDO_LOG:-/dev/null}"
if [[ "${WIZARD_FAIL:-}" == "apt" && "$1" == "apt-get" ]]; then
    exit 1
fi
exit 0
EOF
cat > "$TEMP_DIR/bin/python3" <<'EOF'
#!/bin/bash
if [[ "${WIZARD_FAIL:-}" == "pip" && "$1" == "-m" && "$2" == "pip" ]]; then
    exit 1
fi
exit 1
EOF
cat > "$TEMP_DIR/bin/code" <<'EOF'
#!/bin/bash
if [[ "${WIZARD_FAIL:-}" == "extension" ]]; then
    exit 1
fi
exit 0
EOF
cat > "$TEMP_DIR/bin/dbus-launch" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$TEMP_DIR/bin/gnome-keyring-daemon" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$TEMP_DIR/bin/startxfce4" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$TEMP_DIR/bin/restore-vscode-extensions" <<EOF
#!/bin/bash
exec bash "$ROOT_DIR/scripts/restore-vscode-extensions" "\$@"
EOF
chmod +x "$TEMP_DIR/bin/"*

BAKED_EXTENSIONS="$TEMP_DIR/baked-extensions"
USER_EXTENSIONS="$TEMP_DIR/user-extensions"
mkdir -p "$BAKED_EXTENSIONS/ms-python.python-1.0" "$USER_EXTENSIONS/ms-python.python-1.0"
printf 'baked\n' > "$BAKED_EXTENSIONS/ms-python.python-1.0/extension.txt"
printf 'user\n' > "$USER_EXTENSIONS/ms-python.python-1.0/extension.txt"
mkdir -p "$BAKED_EXTENSIONS/ms-python.vscode-pylance-1.0"
printf 'pylance\n' > "$BAKED_EXTENSIONS/ms-python.vscode-pylance-1.0/extension.txt"
bash "$ROOT_DIR/scripts/restore-vscode-extensions" "$BAKED_EXTENSIONS" "$USER_EXTENSIONS"
[[ "$(cat "$USER_EXTENSIONS/ms-python.python-1.0/extension.txt")" == "user" ]]
[[ "$(cat "$USER_EXTENSIONS/ms-python.vscode-pylance-1.0/extension.txt")" == "pylance" ]]

run_wizard_failure() {
    local failure="$1"
    local packages="${2:-}"
    local extensions="${3:-}"
    local home="$TEMP_DIR/home-$failure"
    mkdir -p "$home/.config"
    if HOME="$home" PATH="$TEMP_DIR/bin:$PATH" \
        WIZARD_FAIL="$failure" WIZARD_PACKAGE_CHOICES="$packages" \
        WIZARD_EXTENSION_CHOICES="$extensions" WIZARD_SUDO_LOG="$TEMP_DIR/sudo-$failure.log" \
        bash "$ROOT_DIR/first-run-wizard.sh" >"$TEMP_DIR/wizard-$failure.log" 2>&1; then
        echo "Wizard unexpectedly succeeded after $failure installation failure." >&2
        exit 1
    fi
    [[ ! -f "$home/.config/agy-setup-done" ]]
    grep -q "not marked complete" "$home/.config/agy-setup.log"
}

run_wizard_failure apt htop
run_wizard_failure pip pre-commit
run_wizard_failure extension "" golang.go

SKIP_HOME="$TEMP_DIR/home-skip"
mkdir -p "$SKIP_HOME/.config"
HOME="$SKIP_HOME" PATH="$TEMP_DIR/bin:$PATH" WIZARD_CONFIRM_RC=1 \
    WIZARD_SUDO_LOG="$TEMP_DIR/sudo-skip.log" \
    bash "$ROOT_DIR/first-run-wizard.sh" >"$TEMP_DIR/wizard-skip.log" 2>&1
[[ -f "$SKIP_HOME/.config/agy-setup-done" ]]

ADB_HOME="$TEMP_DIR/home-adb"
mkdir -p "$ADB_HOME/.config"
HOME="$ADB_HOME" PATH="$TEMP_DIR/bin:$PATH" WIZARD_PACKAGE_CHOICES="android-sdk-platform-tools-common" \
    WIZARD_SUDO_LOG="$TEMP_DIR/sudo-adb.log" \
    bash "$ROOT_DIR/first-run-wizard.sh" >"$TEMP_DIR/wizard-adb.log" 2>&1
grep -q 'apt-get install -y android-sdk-platform-tools-common adb fastboot' "$TEMP_DIR/sudo-adb.log"
[[ -f "$ADB_HOME/.config/agy-setup-done" ]]

TRUST_HOME="$TEMP_DIR/home-trust"
mkdir -p "$TRUST_HOME/.config/Code/User"
touch "$TRUST_HOME/.config/agy-setup-done"
printf '{"security.workspace.trust.enabled":false}\n' > "$TRUST_HOME/.config/Code/User/settings.json"
HOME="$TRUST_HOME" PATH="$TEMP_DIR/bin:$PATH" \
    bash "$ROOT_DIR/vnc_startup.sh" >"$TEMP_DIR/vnc-trust.log" 2>&1
[[ "$(jq -r '.["security.workspace.trust.enabled"]' "$TRUST_HOME/.config/Code/User/settings.json")" == "true" ]]
jq '.["security.workspace.trust.enabled"] = false' "$TRUST_HOME/.config/Code/User/settings.json" > "$TEMP_DIR/settings.json"
mv "$TEMP_DIR/settings.json" "$TRUST_HOME/.config/Code/User/settings.json"
HOME="$TRUST_HOME" PATH="$TEMP_DIR/bin:$PATH" \
    bash "$ROOT_DIR/vnc_startup.sh" >"$TEMP_DIR/vnc-trust-again.log" 2>&1
[[ "$(jq -r '.["security.workspace.trust.enabled"]' "$TRUST_HOME/.config/Code/User/settings.json")" == "false" ]]

if (cd "$ROOT_DIR" && PATH="$TEMP_DIR/bin:$PATH" bash "$ROOT_DIR/update.sh" </dev/null) \
    >"$TEMP_DIR/updater-fetch-failure.log" 2>&1; then
    echo "Updater did not stop when version discovery and manual input failed." >&2
    exit 1
fi
grep -q "falling back to manual entry" "$TEMP_DIR/updater-fetch-failure.log"
grep -q "Valid version and build ID are required" "$TEMP_DIR/updater-fetch-failure.log"

echo "Review-fix tests passed."
