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

# Layer 5: AntiGravity & LazyGit
ENV LAZYGIT_VERSION=0.40.2
ARG CACHE_BUST=1
RUN curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list > /dev/null && \
    apt-get update && apt-get install -y --no-install-recommends antigravity && \
    ARCH_LG=$(dpkg --print-architecture | sed 's/amd64/x86_64/') && \
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${ARCH_LG}.tar.gz" && \
    tar xf lazygit.tar.gz lazygit && \
    install lazygit /usr/local/bin && \
    rm lazygit.tar.gz lazygit && \
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
    mkdir -p /home/dev/.vnc

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
