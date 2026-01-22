FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install common tools and XFCE desktop
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gnupg \
    lsb-release \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    novnc \
    websockify \
    gnome-keyring \
    libsecret-1-0 \
    curl \
    wget \
    git \
    git-gui \
    default-jre \
    sudo \
    python3 \
    python3-numpy \
    net-tools \
    dbus-x11 \
    software-properties-common \
    wmctrl \
    && apt-get purge -y xfce4-power-manager xfce4-screensaver light-locker \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS (v22.x)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python 3.13
RUN add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.13 python3.13-venv python3.13-dev && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.13 - --break-system-packages && \
    python3.13 -m pip install numpy --break-system-packages && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Google Chrome Stable
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable && \
    sed -i 's/exec -a "$0" "$HERE\/chrome" "$@"/exec -a "$0" "$HERE\/chrome" --password-store=basic "$@"/' /opt/google/chrome/google-chrome && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin iptables && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Google AntiGravity
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | tee /etc/apt/sources.list.d/antigravity.list > /dev/null && \
    apt-get update && apt-get install -y antigravity && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Note: Antigravity manages its Chrome extension automatically.
# If manual extension loading is needed, Chrome can be started with:
#   google-chrome --load-extension=/opt/antigravity/chrome-extension
# The previous ExtensionInstallForcelist policy was removed as it requires
# a valid 32-character extension ID (a-p only) which must be generated from
# the extension's public key.

# Install LazyGit
ENV LAZYGIT_VERSION=0.40.2
RUN curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
    tar xf lazygit.tar.gz lazygit && \
    install lazygit /usr/local/bin && \
    rm lazygit.tar.gz lazygit

# Create a non-root user 'dev'
RUN useradd -m -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG docker dev

# Set up VNC and NoVNC directories
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Copy startup scripts and fake proc files
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY vnc_startup.sh /usr/local/bin/vnc_startup.sh
COPY fake_version /etc/fake_version
COPY fake_osrelease /etc/fake_osrelease
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/vnc_startup.sh && \
    chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/vnc_startup.sh

# Switch to non-root user
USER dev
WORKDIR /home/dev

# Create .vnc directory
RUN mkdir -p /home/dev/.vnc

# Expose VNC port (5901) and NoVNC port (6080)
EXPOSE 5901 6080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
