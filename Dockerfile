# syntax=docker/dockerfile:1
# Dockerfile for a customized Debian Bookworm image with essential networking and system tools, multiple container runtimes, and shell enhancements
# Enable error checking for the Dockerfile
# Base image stage: Debian Bookworm with essential tools and shell enhancements

FROM debian:bookworm AS base

ARG TARGETARCH

# Set environment variables for terminal, locale, and non-interactive apt
ENV TERM=xterm-kitty \
    LANG=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Keep apt cache for BuildKit caching to speed up builds
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Upgrade all packages to the latest version using cached apt directories
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    apt-get update && apt-get full-upgrade -y

# Install essential utilities with BuildKit cache mounts for faster builds
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    apt-get install -y --no-install-recommends \
    apache2-utils \
    bash \
    bird \
    bridge-utils \
    conntrack \
    coreutils \
    ca-certificates \
    curl \
    dhcping \
    dnsutils \
    ethtool \
    e2fsprogs \
    file \
    fping \
    fzf \
    gdisk \
    git \
    httpie \
    iftop \
    iperf \
    iperf3 \
    iproute2 \
    ipset \
    iptables \
    iputils-ping \
    ipvsadm \
    jq \
    mtr \
    netcat-openbsd \
    nftables \
    ngrep \
    nmap \
    openssh-client \
    openssl \
    python3-pip \
    python3-setuptools \
    pipx \
    socat \
    speedtest-cli \
    strace \
    sudo \
    swaks \
    tcpdump \
    tcptraceroute \
    termshark \
    tshark \
    util-linux \
    vim \
    zsh \
    zip \
    btop \
    procps \
    kitty-terminfo \
    htop \
    tmux \
    screen \
    rsync \
    fail2ban \
    logrotate \
    ncdu \
    traceroute \
    sysstat \
    lsof \
    nmon \
    whois \
    bind9-utils \
    nfs-common \
    telnet \
    unzip \
    lynx \
    wget \
    net-tools \
    wireguard-tools \
    magic-wormhole \
    iotop

# Copy the 'uv' binary and its helper to /bin from the external image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install useful uv tool 'check-tls' with cache mount for faster installs
RUN --mount=type=cache,target=/root/.cache \
    uv tool install check-tls

# Install Oh My Zsh and essential plugins for an enhanced shell experience.
# This includes auto-suggestions, syntax highlighting, completions, and the Powerlevel10k theme.
# A cache mount is used to speed up git clone operations during repeated builds.
RUN --mount=type=cache,target=/root/.cache <<EOF
set -eux

# Install Oh My Zsh non-interactively
curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended

# Define the custom plugins and themes directory
ZSH_CUSTOM=/root/.oh-my-zsh/custom

# Clone Zsh plugins and Powerlevel10k theme
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
git clone --depth 1 https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions
git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting
git clone --depth 1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k

case "$TARGETARCH" in
    amd64)   PLATFORM="x86_64" ;;
    386)     PLATFORM="i686" ;;
    arm64)   PLATFORM="aarch64" ;;
    arm)     PLATFORM="arm" ;; 
    ppc64le) PLATFORM="ppc64le" ;;
    *)       PLATFORM="$TARGETARCH" ;;
esac

${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/install -s linux -m ${PLATFORM}

EOF

# Use COPY --link for better layer reuse when copying config files and scripts
COPY --link configs/zshrc /root/.zshrc
COPY --link configs/p10k.zsh /root/.p10k.zsh
COPY --link --chmod=755 tools/transfer.sh /usr/local/bin/transfer.sh

# Default command to start zsh shell and exit cleanly
WORKDIR /root

# Default command to start zsh shell and exit cleanly
CMD [ "bash", "-c", "zsh; exit 0" ]

# Docker CLI tools layer based on base image: installs Docker components

# Docker CLI tools layer based on base image
FROM base AS docker
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} <<EOF

set -ex

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository to apt sources list
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Podman layer based on base image: installs Podman and related tools
EOF

# podman layer based on base image
FROM base AS podman
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    apt-get update && apt-get install -y --no-install-recommends \
    podman \
    fuse-overlayfs && \
    apt-get clean

# Copy podman storage configuration file
# nerdctl stage: downloads and installs the latest nerdctl release with checksum verification
COPY --link configs/podman-storage.conf /root/.config/containers/storage.conf


# nerdctl stage (repeated, possibly for multi-stage build)
FROM base AS nerdctl

ARG TARGETARCH

RUN --mount=type=cache,target=/tmp/nerdctl \
    set -e; \
    # Detect correct GitHub architecture name
        case "$TARGETARCH" in \
        amd64) ARCH=amd64 ;; \
        arm64) ARCH=arm64 ;; \
        arm) ARCH=arm-v7 ;; \
        *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac; \
    # Get latest release tag from GitHub API
    TAG=$(curl -s https://api.github.com/repos/containerd/nerdctl/releases/latest | jq -r .tag_name); \
    FILE="nerdctl-${TAG#v}-linux-${ARCH}.tar.gz"; \
    URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/${FILE}"; \
    CHECKSUM_URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/SHA256SUMS"; \
    ARCHIVE="/tmp/nerdctl/$FILE"; \
    if [ ! -f "$ARCHIVE" ]; then \
        echo "Downloading $URL"; \
        curl -fsSL "$URL" -o "$ARCHIVE"; \
        # Download checksum file and verify
        curl -fsSL "$CHECKSUM_URL" -o "/tmp/nerdctl/SHA256SUMS"; \
        cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c - || (echo "Checksum verification failed" && exit 1); \
    else \
        echo "Using cached $ARCHIVE"; \
        # Verify if SHA256SUMS is cached and checksum is valid
        if [ ! -f "/tmp/nerdctl/SHA256SUMS" ] || ! (cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c -); then \
            echo "Cached SHA256SUMS missing or checksum failed. Redownloading."; \
            # Redownload archive and checksum
            curl -fsSL "$URL" -o "$ARCHIVE"; \
            curl -fsSL "$CHECKSUM_URL" -o "/tmp/nerdctl/SHA256SUMS"; \
            cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c - || (echo "Checksum verification failed after redownload" && exit 1); \
        else \
            echo "Cached file and checksum are valid."; \
        fi; \
    fi; \
    tar Cxzvvf /usr/local "$ARCHIVE"


# nerdctl stage (repeated, possibly for multi-stage build)
FROM base AS containerd

ARG TARGETARCH

RUN --mount=type=cache,target=/tmp/nerdctl \
    set -e; \
    # Detect correct GitHub architecture name
        case "$TARGETARCH" in \
        amd64) ARCH=amd64 ;; \
        arm64) ARCH=arm64 ;; \
        arm) ARCH=arm-v7 ;; \
        *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac; \
    # Get latest release tag from GitHub API
    TAG=$(curl -s https://api.github.com/repos/containerd/nerdctl/releases/latest | jq -r .tag_name); \
    FILE="nerdctl-full-${TAG#v}-linux-${ARCH}.tar.gz"; \
    URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/${FILE}"; \
    CHECKSUM_URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/SHA256SUMS"; \
    ARCHIVE="/tmp/nerdctl/$FILE"; \
    if [ ! -f "$ARCHIVE" ]; then \
        echo "Downloading $URL"; \
        curl -fsSL "$URL" -o "$ARCHIVE"; \
        # Download checksum file and verify
        curl -fsSL "$CHECKSUM_URL" -o "/tmp/nerdctl/SHA256SUMS"; \
        cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c - || (echo "Checksum verification failed" && exit 1); \
    else \
        echo "Using cached $ARCHIVE"; \
        # Verify if SHA256SUMS is cached and checksum is valid
        if [ ! -f "/tmp/nerdctl/SHA256SUMS" ] || ! (cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c -); then \
            echo "Cached SHA256SUMS missing or checksum failed. Redownloading."; \
            # Redownload archive and checksum
            curl -fsSL "$URL" -o "$ARCHIVE"; \
            curl -fsSL "$CHECKSUM_URL" -o "/tmp/nerdctl/SHA256SUMS"; \
            cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c - || (echo "Checksum verification failed after redownload" && exit 1); \
        else \
            echo "Cached file and checksum are valid."; \
        fi; \
    fi; \
    tar Cxzvvf /usr/local "$ARCHIVE"

COPY --link --chmod=755 entrypoint-containerd.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
