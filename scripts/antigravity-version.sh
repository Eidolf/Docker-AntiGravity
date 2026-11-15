validate_antigravity_hub_values() {
    [[ "${1:-}" =~ ^[0-9]+([.][0-9]+){2}$ ]] &&
        [[ "${2:-}" =~ ^[1-9][0-9]*$ ]]
}

read_manual_antigravity_hub_values() {
    while true; do
        if ! IFS= read -r -p "Antigravity Hub Version (e.g. 2.1.4): " HUB_VER; then
            return 1
        fi
        if [[ "$HUB_VER" =~ ^[0-9]+([.][0-9]+){2}$ ]]; then
            break
        fi
        echo "Invalid version. Use three numeric components, for example 2.1.4." >&2
    done

    while true; do
        if ! IFS= read -r -p "Antigravity Hub Build ID (e.g. 6481382726303744): " HUB_BUILD; then
            return 1
        fi
        if [[ "$HUB_BUILD" =~ ^[1-9][0-9]*$ ]]; then
            break
        fi
        echo "Invalid build ID. Use digits only." >&2
    done
}
