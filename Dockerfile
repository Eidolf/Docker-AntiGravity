FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Layer 1: Core System & VNC Setup
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        lsb-release \
        curl \
        wget \
        jq \
        sudo \
        git \
        net-tools \
        dbus-x11 \
        software-properties-common \
        wmctrl \
        tigervnc-standalone-server \
        tigervnc-tools \
        novnc \
        websockify \
        # Layer 2 Components
        xfce4-session \
        xfce4-panel \
        xfce4-settings \
        xfwm4 \
        xfdesktop4 \
        xfce4-terminal \
        xfce4-clipman-plugin \
        xfce4-notifyd \
        xfce4-taskmanager \
        gnome-keyring \
        libsecret-1-0 \
        hicolor-icon-theme \
        adwaita-icon-theme \
        xfce4-appfinder \
        thunar \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Layer 3: Node.js (v24.x) and Python (using 3.14 for latest support)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y --no-install-recommends \
        nodejs \
        python3.14 \
        python3.14-venv \
        python3.14-dev \
        gosu \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 1 \
    && curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.14 - --break-system-packages \
    && python3 -m pip install --ignore-installed websockify numpy --break-system-packages \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Layer 4: Browsers & Docker CLI
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list && \
        apt-get update && apt-get install -y --no-install-recommends google-chrome-stable && \
        if [ -f /opt/google/chrome/google-chrome ]; then \
            sed -i 's/exec -a "$0" "$HERE\/chrome" "$@"/exec -a "$0" "$HERE\/chrome" --password-store=basic "$@"/' /opt/google/chrome/google-chrome; \
        fi; \
        ln -sf /usr/bin/google-chrome-stable /usr/local/bin/google-chrome; \
    else \
        mkdir -p /etc/apt/keyrings && \
        (for i in 1 2 3; do curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x82BB6851C64F6880&options=mr" | gpg --dearmor -o /etc/apt/keyrings/xtradeb.gpg && break || sleep 5; done) && \
        echo "deb [signed-by=/etc/apt/keyrings/xtradeb.gpg] http://ppa.launchpad.net/xtradeb/apps/ubuntu noble main" | tee /etc/apt/sources.list.d/xtradeb-apps.list > /dev/null && \
        (for i in 1 2 3; do apt-get update && apt-get install -y --no-install-recommends chromium && break || sleep 5; done) && \
        printf '#!/bin/bash\nexec /usr/bin/chromium --no-sandbox --test-type --disable-dev-shm-usage --no-first-run --no-default-browser-check "$@"' > /usr/local/bin/google-chrome && \
        chmod +x /usr/local/bin/google-chrome; \
    fi && \
    ln -sf /usr/local/bin/google-chrome /usr/local/bin/google-chrome-stable && \
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/google-chrome 100 && \
    update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/local/bin/google-chrome 100 && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-compose-plugin iptables fuse-overlayfs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Layer 5: AntiGravity v2.0 (Desktop & IDE) & LazyGit
ENV LAZYGIT_VERSION=0.40.2
ENV ANTIGRAVITY_HUB_VERSION=2.1.4
ENV ANTIGRAVITY_HUB_BUILD=6481382726303744
ENV ANTIGRAVITY_IDE_VERSION=2.1.1
ENV ANTIGRAVITY_IDE_BUILD=6123990880747520

RUN apt-get update && apt-get install -y --no-install-recommends \
        alsa-utils \
        libasound2t64 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libatspi2.0-0 \
        libcairo2 \
        libcups2 \
        libdbus-1-3 \
        libexpat1 \
        libgbm1 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libx11-6 \
        libxcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxkbcommon0 \
        libxkbfile1 \
        libxrandr2 \
        libsecret-1-0 \
        libwebkit2gtk-4.1-0 \
        libsoup-3.0-0 \
        xdg-utils \
    && ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        ARCH_SUB="linux-x64"; \
        ARCH_LG="x86_64"; \
    else \
        ARCH_SUB="linux-arm"; \
        ARCH_LG="arm64"; \
    fi && \
    # 1. Install LazyGit
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${ARCH_LG}.tar.gz" && \
    tar xf lazygit.tar.gz lazygit && \
    install lazygit /usr/local/bin && \
    rm lazygit.tar.gz lazygit && \
    # 2. Download and install Antigravity Hub/Desktop v2.0
    curl -fsSL -o /tmp/antigravity-hub.tar.gz "https://storage.googleapis.com/antigravity-public/antigravity-hub/${ANTIGRAVITY_HUB_VERSION}-${ANTIGRAVITY_HUB_BUILD}/${ARCH_SUB}/Antigravity.tar.gz" && \
    mkdir -p /opt/antigravity-desktop && \
    tar -xzf /tmp/antigravity-hub.tar.gz -C /opt/antigravity-desktop --strip-components=1 && \
    rm /tmp/antigravity-hub.tar.gz && \
    ln -sf /opt/antigravity-desktop/antigravity /usr/local/bin/antigravity && \
    # 3. Download and install Antigravity IDE v2.0
    curl -fsSL -o /tmp/antigravity-ide.tar.gz "https://dl.google.com/release2/j0qc3/antigravity/stable/${ANTIGRAVITY_IDE_VERSION}-${ANTIGRAVITY_IDE_BUILD}/${ARCH_SUB}/Antigravity%20IDE.tar.gz" && \
    mkdir -p /opt/antigravity-ide && \
    tar -xzf /tmp/antigravity-ide.tar.gz -C /opt/antigravity-ide --strip-components=1 && \
    rm /tmp/antigravity-ide.tar.gz && \
    # 4. Create wrapper script for Antigravity IDE
    printf '#!/bin/bash\nXDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}\nif [[ -f $XDG_CONFIG_HOME/antigravity-ide-flags.conf ]]; then\n    ANTIGRAVITY_IDE_USER_FLAGS="$(sed '\''s/#.*//'\'' $XDG_CONFIG_HOME/antigravity-ide-flags.conf | tr '\''\\n'\'' '\'' '\'')"\nfi\nexec /opt/antigravity-ide/bin/antigravity-ide "$@" $ANTIGRAVITY_IDE_USER_FLAGS\n' > /usr/local/bin/antigravity-ide && \
    chmod +x /usr/local/bin/antigravity-ide && \
    # 5. Download and install icons and desktop files
    curl -fsSL -o /usr/share/pixmaps/antigravity.png "https://aur.archlinux.org/cgit/aur.git/plain/antigravity.png?h=antigravity" && \
    if [ -f /opt/antigravity-ide/resources/app/resources/linux/code.png ]; then \
        cp /opt/antigravity-ide/resources/app/resources/linux/code.png /usr/share/pixmaps/antigravity-ide.png; \
    fi && \
    # 6. Create Desktop entries
    # Antigravity Desktop
    printf '[Desktop Entry]\nName=Antigravity\nComment=Experience liftoff\nGenericName=Agentic Platform\nExec=/usr/local/bin/antigravity %%U\nIcon=antigravity\nType=Application\nStartupNotify=false\nStartupWMClass=Antigravity\nCategories=Development;Utility;\n' > /usr/share/applications/antigravity.desktop && \
    # Antigravity IDE
    printf '[Desktop Entry]\nName=Antigravity IDE\nComment=Experience liftoff\nGenericName=Text Editor\nExec=/usr/local/bin/antigravity-ide %%F\nIcon=antigravity-ide\nType=Application\nStartupNotify=false\nStartupWMClass=antigravity-ide\nCategories=TextEditor;Development;IDE;\nMimeType=application/x-antigravity-ide-workspace;\nActions=new-empty-window;\nKeywords=vscode;\n\n[Desktop Action new-empty-window]\nName=New Empty Window\nExec=/usr/local/bin/antigravity-ide --new-window %%F\nIcon=antigravity-ide\n' > /usr/share/applications/antigravity-ide.desktop && \
    # Antigravity IDE URL Handler
    printf '[Desktop Entry]\nName=Antigravity IDE - URL Handler\nComment=Experience liftoff\nGenericName=Text Editor\nExec=/usr/local/bin/antigravity-ide --open-url %%U\nIcon=antigravity-ide\nType=Application\nNoDisplay=true\nStartupNotify=true\nCategories=Utility;TextEditor;Development;IDE;\nMimeType=x-scheme-handler/antigravity-ide;\nKeywords=vscode;\n' > /usr/share/applications/antigravity-ide-url-handler.desktop && \
    # 7. Create In-Place Updater script and Desktop shortcut
    printf '#!/bin/bash\nset -e\necho "Checking architecture..."\nARCH=$(dpkg --print-architecture)\nif [ "$ARCH" = "amd64" ]; then\n    ARCH_SUB="linux-x64"\nelse\n    ARCH_SUB="linux-arm"\nfi\necho "Fetching latest versions from Homebrew Casks..."\nVERSIONS=$(python3 -c '\''\nimport urllib.request, re\ndef get_cask_ver(cask):\n    try:\n        url = f"https://raw.githubusercontent.com/Homebrew/homebrew-cask/main/Casks/a/{cask}.rb"\n        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})\n        with urllib.request.urlopen(req) as response:\n            content = response.read().decode("utf-8")\n            match = re.search(r"version\\s+\\"([^\\"]+)\\"", content)\n            if match:\n                parts = match.group(1).split(",")\n                if len(parts) == 2:\n                    return parts[0], parts[1]\n    except Exception as e:\n        print(f"Error fetching {cask}: {e}")\n    return None, None\nhub_v, hub_b = get_cask_ver("antigravity")\nide_v, ide_b = get_cask_ver("antigravity-ide")\nprint(f"{hub_v}|{hub_b}|{ide_v}|{ide_b}")\n'\'')\nHUB_VER=$(echo "$VERSIONS" | cut -d"|" -f1)\nHUB_BUILD=$(echo "$VERSIONS" | cut -d"|" -f2)\nIDE_VER=$(echo "$VERSIONS" | cut -d"|" -f3)\nIDE_BUILD=$(echo "$VERSIONS" | cut -d"|" -f4)\nif [ -z "$HUB_VER" ] || [ -z "$HUB_BUILD" ] || [ -z "$IDE_VER" ] || [ -z "$IDE_BUILD" ]; then\n    echo "Error: Failed to fetch version info. Please enter versions manually:"\n    read -p "Antigravity Hub Version (e.g. 2.1.4): " HUB_VER\n    read -p "Antigravity Hub Build ID (e.g. 6481382726303744): " HUB_BUILD\n    read -p "Antigravity IDE Version (e.g. 2.1.1): " IDE_VER\n    read -p "Antigravity IDE Build ID (e.g. 6123990880747520): " IDE_BUILD\nfi\necho "Targeting versions:"\necho "  Antigravity: $HUB_VER (Build $HUB_BUILD)"\necho "  Antigravity IDE: $IDE_VER (Build $IDE_BUILD)"\necho "Updating Antigravity..."\ncurl -fsSL -o /tmp/antigravity-hub.tar.gz "https://storage.googleapis.com/antigravity-public/antigravity-hub/${HUB_VER}-${HUB_BUILD}/${ARCH_SUB}/Antigravity.tar.gz"\nsudo rm -rf /opt/antigravity-desktop/*\nsudo tar -xzf /tmp/antigravity-hub.tar.gz -C /opt/antigravity-desktop --strip-components=1\nrm /tmp/antigravity-hub.tar.gz\nsudo ln -sf /opt/antigravity-desktop/antigravity /usr/local/bin/antigravity\necho "Updating Antigravity IDE..."\ncurl -fsSL -o /tmp/antigravity-ide.tar.gz "https://dl.google.com/release2/j0qc3/antigravity/stable/${IDE_VER}-${IDE_BUILD}/${ARCH_SUB}/Antigravity%%20IDE.tar.gz"\nsudo rm -rf /opt/antigravity-ide/*\nsudo tar -xzf /tmp/antigravity-ide.tar.gz -C /opt/antigravity-ide --strip-components=1\nrm /tmp/antigravity-ide.tar.gz\necho "Update complete! Please restart any running instances of Antigravity or Antigravity IDE."\nread -p "Press Enter to exit..."\n' > /usr/local/bin/update-in-place && \
    chmod +x /usr/local/bin/update-in-place && \
    printf '[Desktop Entry]\nName=Update Antigravity\nComment=Update Antigravity and Antigravity IDE in-place\nExec=xfce4-terminal -e /usr/local/bin/update-in-place\nIcon=system-software-update\nType=Application\nTerminal=false\nCategories=System;Utility;\n' > /usr/share/applications/update-antigravity.desktop && \
    # Clean up APT
    apt-get clean && rm -rf /var/lib/apt/lists/*


# Final Setup: User, scripts, and permissions
# Ubuntu 24.04 has a default 'ubuntu' user (UID 1000) that we must remove to reuse UID 1000 for 'dev'
RUN (id -u ubuntu >/dev/null 2>&1 && userdel -f ubuntu || true) && \
    (getent group ubuntu >/dev/null 2>&1 && groupdel ubuntu || true) && \
    groupadd -g 1000 dev && \
    useradd -u 1000 -g dev -m -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG docker dev && \
    ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html && \
    mkdir -p /home/dev/.vnc && \
    mkdir -p /home/dev/Desktop && \
    cp /usr/share/applications/antigravity.desktop /home/dev/Desktop/ && \
    cp /usr/share/applications/antigravity-ide.desktop /home/dev/Desktop/ && \
    ( [ -f /usr/share/applications/update-antigravity.desktop ] && cp /usr/share/applications/update-antigravity.desktop /home/dev/Desktop/ || true ) && \
    chmod +x /home/dev/Desktop/*.desktop && \
    chown -R dev:dev /home/dev

# Layer 6: Claude Code CLI
USER dev
WORKDIR /home/dev
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY vnc_startup.sh /usr/local/bin/vnc_startup.sh
COPY fake_version /etc/fake_version
COPY fake_osrelease /etc/fake_osrelease

RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/vnc_startup.sh && \
    chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/vnc_startup.sh

WORKDIR /home/dev
EXPOSE 5901 6080

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
