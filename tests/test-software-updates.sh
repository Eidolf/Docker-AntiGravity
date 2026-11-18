#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/bin" "$TEMP_DIR/home"

cat >"$TEMP_DIR/bin/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_CALLS"
[[ "$1" == "-n" ]]
shift
exec "$@"
EOF
cat >"$TEMP_DIR/bin/apt-get" <<'EOF'
#!/bin/bash
if [[ "$*" == *" update" ]]; then
    echo "repository refresh"
    exit "${TEST_REFRESH_STATUS:-0}"
fi
printf '%s\n' "$*" >>"$TEST_INSTALLS"
echo "installation output"
exit "${TEST_INSTALL_STATUS:-0}"
EOF
cat >"$TEMP_DIR/bin/apt" <<'EOF'
#!/bin/bash
echo "Listing..."
if [[ "${TEST_UPDATES:-1}" == 1 ]]; then
    echo "code/stable 2.0 amd64 [upgradable from: 1.0]"
    echo "libexample:amd64/stable 3.0 amd64 [upgradable from: 2.0]"
fi
exit "${TEST_LIST_STATUS:-0}"
EOF
cat >"$TEMP_DIR/bin/zenity" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_DIALOGS"
if [[ "$*" == *"--list"* ]]; then
    printf '%s' "${TEST_SELECTION:-}"
    exit "${TEST_DIALOG_STATUS:-0}"
fi
EOF
cat >"$TEMP_DIR/bin/xfce4-terminal" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_TERMINAL"
exit "${TEST_TERMINAL_STATUS:-0}"
EOF
cat >"$TEMP_DIR/bin/dpkg-query" <<'EOF'
#!/bin/bash
printf '%s\n' "${TEST_PACKAGE_STATUS:-installed}"
EOF
cat >"$TEMP_DIR/bin/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TEMP_DIR/bin/"*
export HOME="$TEMP_DIR/home" PATH="$TEMP_DIR/bin:$PATH"
export XDG_CACHE_HOME="$HOME/.cache"
export TEST_CALLS="$TEMP_DIR/calls" TEST_INSTALLS="$TEMP_DIR/installs"
export TEST_DIALOGS="$TEMP_DIR/dialogs" TEST_TERMINAL="$TEMP_DIR/terminal"
UPDATER="$ROOT_DIR/scripts/software-updates"

bash "$UPDATER" --check >"$TEMP_DIR/check.log"
grep -qx code "$TEMP_DIR/check.log"
grep -qx libexample:amd64 "$TEMP_DIR/check.log"
[[ ! -e "$TEST_INSTALLS" && ! -e "$TEST_DIALOGS" && ! -e "$TEST_TERMINAL" ]]

TEST_UPDATES=0 bash "$UPDATER" --startup >"$TEMP_DIR/startup-empty.log"
[[ ! -e "$TEST_DIALOGS" ]]
TEST_DIALOG_STATUS=1 bash "$UPDATER" --startup >"$TEMP_DIR/startup-cancel.log"
grep -q 'FALSE code 2.0 FALSE libexample:amd64 3.0' "$TEST_DIALOGS"
[[ ! -e "$TEST_INSTALLS" && ! -e "$TEST_TERMINAL" ]]

TEST_SELECTION=code bash "$UPDATER" >"$TEMP_DIR/selected.log"
grep -q -- '--hold --execute bash .* --install code$' "$TEST_TERMINAL"
[[ ! -e "$TEST_INSTALLS" ]]

if TEST_REFRESH_STATUS=100 bash "$UPDATER" --check >"$TEMP_DIR/offline.log" 2>&1; then
    echo "Failed repository refresh was accepted." >&2
    exit 1
fi
grep -q 'Could not refresh' "$TEMP_DIR/offline.log"
if TEST_LIST_STATUS=100 bash "$UPDATER" --check >"$TEMP_DIR/list-failure.log" 2>&1; then
    echo "Failed package listing was accepted." >&2
    exit 1
fi
grep -q 'Could not list' "$TEMP_DIR/list-failure.log"

if TEST_DIALOG_STATUS=5 bash "$UPDATER" >"$TEMP_DIR/dialog-failure.log" 2>&1; then
    echo "Broken selection dialog was accepted." >&2
    exit 1
fi
grep -q 'Could not display the package selection' "$TEMP_DIR/dialog-failure.log"
if TEST_SELECTION=code TEST_TERMINAL_STATUS=1 bash "$UPDATER" >"$TEMP_DIR/terminal-failure.log" 2>&1; then
    echo "Broken update terminal was accepted." >&2
    exit 1
fi
grep -q 'Could not open the update terminal' "$TEMP_DIR/terminal-failure.log"

for invalid in '--yes' 'code;touch /tmp/unwanted' 'code=1.0'; do
    if bash "$UPDATER" --install "$invalid" >"$TEMP_DIR/invalid.log" 2>&1; then
        echo "Invalid package name was accepted: $invalid" >&2
        exit 1
    fi
done
if TEST_PACKAGE_STATUS=config-files bash "$UPDATER" --install code >"$TEMP_DIR/not-installed.log" 2>&1; then
    echo "Uninstalled package was accepted." >&2
    exit 1
fi
[[ ! -e "$TEST_INSTALLS" ]]

bash "$UPDATER" --install code libexample:amd64 >"$TEMP_DIR/install.log"
grep -qx 'install --only-upgrade --no-remove -- code libexample:amd64' "$TEST_INSTALLS"
grep -q 'installation output' "$XDG_CACHE_HOME/agy-updates/install.log"
if TEST_INSTALL_STATUS=100 bash "$UPDATER" --install code >"$TEMP_DIR/install-failure.log" 2>&1; then
    echo "Failed installation was accepted." >&2
    exit 1
fi
grep -q 'Update failed (exit 100)' "$TEMP_DIR/install-failure.log"

echo "Software update tests passed."
