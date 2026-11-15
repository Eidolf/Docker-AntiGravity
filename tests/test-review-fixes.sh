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
if [[ "${UPDATE_TEST:-0}" == "1" ]]; then
    exec "$@"
fi
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
if [[ "${VSCODE_TRUST_MIGRATION_SCRIPT:-}" == "$1" ]]; then
    exec /usr/bin/python3 "$@"
fi
if [[ "$1" == "-c" && "${UPDATE_PYTHON_FAIL:-0}" == "1" ]]; then
    exit 1
fi
if [[ "$1" == "-c" && "${UPDATE_TEST:-0}" == "1" ]]; then
    printf '2.1.4|6481382726303744\n'
    exit 0
fi
exit 1
EOF
cat > "$TEMP_DIR/bin/dpkg" <<'EOF'
#!/bin/sh
printf 'amd64\n'
EOF
cat > "$TEMP_DIR/bin/curl" <<'EOF'
#!/bin/bash
archive=""
while (($#)); do
    if [[ "$1" == "-o" ]]; then
        shift
        archive="$1"
    fi
    shift
done
printf '%s\n' "$archive" >> "$UPDATE_ARCHIVE_LOG"
printf 'fake archive\n' > "$archive"
sleep "${UPDATE_CURL_DELAY:-0}"
EOF
cat > "$TEMP_DIR/bin/tar" <<'EOF'
#!/bin/bash
destination=""
while (($#)); do
    if [[ "$1" == "-C" ]]; then
        shift
        destination="$1"
    fi
    shift
done
mkdir -p "$destination"
if [[ "${UPDATE_FAIL_EXTRACT:-0}" == "1" ]]; then
    printf 'partial\n' > "$destination/partial"
    exit 1
fi
printf 'new installation\n' > "$destination/antigravity"
chmod +x "$destination/antigravity"
EOF
cat > "$TEMP_DIR/bin/mv" <<'EOF'
#!/bin/bash
args=("$@")
if [[ "${args[0]:-}" == "--" ]]; then
    args=("${args[@]:1}")
fi
if [[ "${UPDATE_FAIL_STAGE_MOVE:-0}" == "1" &&
    "${args[0]:-}" == *".staging."* &&
    "${args[1]:-}" == "${ANTIGRAVITY_INSTALL_DIR:-}" ]]; then
    exit 1
fi
exec /bin/mv "$@"
EOF
cat > "$TEMP_DIR/bin/ln" <<'EOF'
#!/bin/sh
exit 0
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
mkdir -p "$BAKED_EXTENSIONS/ms-python.python-2.0" "$USER_EXTENSIONS/ms-python.python-1.0"
printf 'baked\n' > "$BAKED_EXTENSIONS/ms-python.python-2.0/extension.txt"
printf 'user\n' > "$USER_EXTENSIONS/ms-python.python-1.0/extension.txt"
mkdir -p "$BAKED_EXTENSIONS/ms-python.vscode-pylance-1.0"
printf 'pylance\n' > "$BAKED_EXTENSIONS/ms-python.vscode-pylance-1.0/extension.txt"
cat > "$BAKED_EXTENSIONS/extensions.json" <<EOF
[
  {"identifier":{"id":"ms-python.python"},"version":"2.0","relativeLocation":"ms-python.python-2.0","location":{"path":"$BAKED_EXTENSIONS/ms-python.python-2.0","scheme":"file"}},
  {"identifier":{"id":"ms-python.vscode-pylance"},"version":"1.0","relativeLocation":"ms-python.vscode-pylance-1.0","location":{"path":"$BAKED_EXTENSIONS/ms-python.vscode-pylance-1.0","scheme":"file"}}
]
EOF
cat > "$USER_EXTENSIONS/extensions.json" <<'EOF'
[
  {"identifier":{"id":"golang.go"},"version":"1.0","relativeLocation":"golang.go-1.0","location":{"path":"/home/dev/.vscode/extensions/golang.go-1.0","scheme":"file"}},
  {"identifier":{"id":"ms-python.python"},"version":"1.0","relativeLocation":"ms-python.python-1.0","location":{"path":"/home/dev/.vscode/extensions/ms-python.python-1.0","scheme":"file"}}
]
EOF
bash "$ROOT_DIR/scripts/restore-vscode-extensions" "$BAKED_EXTENSIONS" "$USER_EXTENSIONS"
[[ "$(cat "$USER_EXTENSIONS/ms-python.python-1.0/extension.txt")" == "user" ]]
[[ "$(cat "$USER_EXTENSIONS/ms-python.vscode-pylance-1.0/extension.txt")" == "pylance" ]]
jq -e --arg python "$USER_EXTENSIONS/ms-python.python-1.0" \
    'length == 3 and any(.[]; .identifier.id == "ms-python.python" and .version == "1.0" and .location.path == $python)' \
    "$USER_EXTENSIONS/extensions.json" >/dev/null
bash "$ROOT_DIR/scripts/restore-vscode-extensions" "$BAKED_EXTENSIONS" "$USER_EXTENSIONS"
[[ "$(jq 'length' "$USER_EXTENSIONS/extensions.json")" == "3" ]]

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
cat > "$TRUST_HOME/.config/Code/User/settings.json" <<'EOF'
{
    // Keep this comment and the trailing comma intact.
    "security.workspace.trust.enabled": false,
    "editor.fontSize": 14,
}
EOF
HOME="$TRUST_HOME" PATH="$TEMP_DIR/bin:$PATH" \
    VSCODE_TRUST_MIGRATION_SCRIPT="$ROOT_DIR/scripts/enable-vscode-workspace-trust.py" \
    bash "$ROOT_DIR/vnc_startup.sh" >"$TEMP_DIR/vnc-trust.log" 2>&1
grep -q '"security.workspace.trust.enabled": true,' "$TRUST_HOME/.config/Code/User/settings.json"
grep -q 'Keep this comment and the trailing comma intact.' "$TRUST_HOME/.config/Code/User/settings.json"
grep -q '"editor.fontSize": 14,' "$TRUST_HOME/.config/Code/User/settings.json"
sed -i 's/"security.workspace.trust.enabled": true/"security.workspace.trust.enabled": false/' \
    "$TRUST_HOME/.config/Code/User/settings.json"
HOME="$TRUST_HOME" PATH="$TEMP_DIR/bin:$PATH" \
    VSCODE_TRUST_MIGRATION_SCRIPT="$ROOT_DIR/scripts/enable-vscode-workspace-trust.py" \
    bash "$ROOT_DIR/vnc_startup.sh" >"$TEMP_DIR/vnc-trust-again.log" 2>&1
grep -q '"security.workspace.trust.enabled": false,' "$TRUST_HOME/.config/Code/User/settings.json"

TRUST_SYMLINK_HOME="$TEMP_DIR/home-trust-symlink"
SYMLINK_SETTINGS="$TEMP_DIR/dotfiles/settings.json"
mkdir -p "$TRUST_SYMLINK_HOME/.config/Code/User" "$(dirname "$SYMLINK_SETTINGS")"
touch "$TRUST_SYMLINK_HOME/.config/agy-setup-done"
cat > "$SYMLINK_SETTINGS" <<'EOF'
{
    "security.workspace.trust.enabled": false,
}
EOF
/bin/ln -s "$SYMLINK_SETTINGS" "$TRUST_SYMLINK_HOME/.config/Code/User/settings.json"
HOME="$TRUST_SYMLINK_HOME" PATH="$TEMP_DIR/bin:$PATH" \
    VSCODE_TRUST_MIGRATION_SCRIPT="$ROOT_DIR/scripts/enable-vscode-workspace-trust.py" \
    bash "$ROOT_DIR/vnc_startup.sh" >"$TEMP_DIR/vnc-trust-symlink.log" 2>&1
[[ -L "$TRUST_SYMLINK_HOME/.config/Code/User/settings.json" ]]
grep -q '"security.workspace.trust.enabled": true,' "$SYMLINK_SETTINGS"

if (cd "$ROOT_DIR" && PATH="$TEMP_DIR/bin:$PATH" UPDATE_PYTHON_FAIL=1 bash "$ROOT_DIR/update.sh" </dev/null) \
    >"$TEMP_DIR/updater-fetch-failure.log" 2>&1; then
    echo "Updater did not stop when version discovery and manual input failed." >&2
    exit 1
fi
grep -q "falling back to manual entry" "$TEMP_DIR/updater-fetch-failure.log"
grep -q "Valid version and build ID are required" "$TEMP_DIR/updater-fetch-failure.log"

UPDATE_HOME="$TEMP_DIR/update-home"
UPDATE_INSTALL="$TEMP_DIR/antigravity-install"
UPDATE_ARCHIVE_LOG="$TEMP_DIR/update-archives.log"
mkdir -p "$UPDATE_HOME" "$UPDATE_INSTALL"
printf 'old installation\n' > "$UPDATE_INSTALL/antigravity"

run_inplace_update() {
    local output="$1"
    shift
    env HOME="$UPDATE_HOME" PATH="$TEMP_DIR/bin:$PATH" UPDATE_TEST=1 \
        ANTIGRAVITY_INSTALL_DIR="$UPDATE_INSTALL" \
        ANTIGRAVITY_EXECUTABLE_LINK="$TEMP_DIR/antigravity-link" \
        ANTIGRAVITY_UPDATE_LOCK_FILE="$UPDATE_HOME/update.lock" \
        UPDATE_ARCHIVE_LOG="$UPDATE_ARCHIVE_LOG" "$@" \
        bash "$ROOT_DIR/scripts/update-in-place.sh" <<<'' >"$output" 2>&1
}

if run_inplace_update "$TEMP_DIR/update-extract-failure.log" UPDATE_FAIL_EXTRACT=1; then
    echo "Updater unexpectedly succeeded after extraction failure." >&2
    exit 1
fi
[[ "$(cat "$UPDATE_INSTALL/antigravity")" == "old installation" ]]
[[ -z "$(find "$TEMP_DIR" -maxdepth 1 -name 'antigravity-install.staging.*' -print -quit)" ]]

if run_inplace_update "$TEMP_DIR/update-swap-failure.log" UPDATE_FAIL_STAGE_MOVE=1; then
    echo "Updater unexpectedly succeeded after installation replacement failure." >&2
    exit 1
fi
[[ "$(cat "$UPDATE_INSTALL/antigravity")" == "old installation" ]]

run_inplace_update "$TEMP_DIR/update-success.log"
[[ "$(cat "$UPDATE_INSTALL/antigravity")" == "new installation" ]]
[[ "$(stat -c '%a' "$UPDATE_INSTALL")" == "755" ]]

run_inplace_update "$TEMP_DIR/update-concurrent-1.log" UPDATE_CURL_DELAY=0.1 &
update_pid_1=$!
run_inplace_update "$TEMP_DIR/update-concurrent-2.log" UPDATE_CURL_DELAY=0.1 &
update_pid_2=$!
if ! wait "$update_pid_1"; then
    cat "$TEMP_DIR/update-concurrent-1.log" >&2
    exit 1
fi
if ! wait "$update_pid_2"; then
    cat "$TEMP_DIR/update-concurrent-2.log" >&2
    exit 1
fi
[[ "$(sort -u "$UPDATE_ARCHIVE_LOG" | wc -l)" == "5" ]]

echo "Review-fix tests passed."
