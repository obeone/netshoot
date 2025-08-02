# syntax=docker/dockerfile:1
#
# Netshoot: A powerful Docker image for network troubleshooting and analysis.
#
# This Dockerfile builds a customized Debian Bookworm image equipped with a
# comprehensive suite of networking and system tools, multiple container runtimes
# (Docker, Podman, nerdctl), and an enhanced Zsh shell environment with Oh My Zsh.
#

# ==============================================================================
# Base Stage: Debian Bookworm with Essential Tools and Shell Enhancements
# ==============================================================================
FROM debian:bookworm AS base

ARG TARGETARCH

# Set environment variables for terminal, locale, and non-interactive apt.
ENV TERM=xterm-kitty \
    LANG=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Configure apt to keep downloaded packages in the cache.
# This leverages BuildKit caching to speed up subsequent builds.
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Upgrade all packages to their latest versions.
# Uses BuildKit cache mounts to accelerate the process.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    apt-get update && apt-get full-upgrade -y

# Install a comprehensive set of essential utilities for networking and system administration.
# Uses BuildKit cache mounts for faster installation.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    apt-get install -y --no-install-recommends \
    # Networking Tools
    apache2-utils bird bridge-utils conntrack curl dhcping dnsutils ethtool fping httpie iftop iperf iperf3 iproute2 ipset iptables iputils-ping ipvsadm mtr netcat-openbsd nftables ngrep nmap openssh-client socat speedtest-cli swaks tcpdump tcptraceroute termshark tshark traceroute wireguard-tools whois bind9-utils telnet wget net-tools \
    # System & Shell Utilities
    bash coreutils ca-certificates e2fsprogs file fzf gdisk git jq openssl python3-pip python3-setuptools pipx strace sudo util-linux vim zsh zip unzip btop procps kitty-terminfo htop tmux screen rsync fail2ban logrotate ncdu sysstat lsof nmon nfs-common lynx magic-wormhole iotop

# Install 'uv', a fast Python package installer from Astral.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install 'check-tls' using uv for TLS/SSL certificate checking.
RUN --mount=type=cache,target=/root/.cache uv tool install check-tls

# Install Oh My Zsh, essential plugins, and the Powerlevel10k theme.
# This enhances the shell with auto-suggestions, syntax highlighting, and more.
# A cache mount is used to speed up git clone operations during repeated builds.
RUN --mount=type=cache,target=/root/.cache \
    bash -c ' \
    set -eux; \
    \
    # Install Oh My Zsh non-interactively
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended; \
    \
    # Define the custom plugins and themes directory
    ZSH_CUSTOM=/root/.oh-my-zsh/custom; \
    \
    # Clone Zsh plugins and Powerlevel10k theme
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions; \
    git clone --depth 1 https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM}/plugins/zsh-completions; \
    git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting; \
    git clone --depth 1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k; \
    \
    # Install gitstatus for Powerlevel10k
    case "$TARGETARCH" in \
        amd64)   PLATFORM="x86_64" ;; \
        386)     PLATFORM="i686" ;; \
        arm64)   PLATFORM="aarch64" ;; \
        arm)     PLATFORM="arm" ;; \
        ppc64le) PLATFORM="ppc64le" ;; \
        *)       PLATFORM="$TARGETARCH" ;; \
    esac; \
    ${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/install -s linux -m ${PLATFORM}; \
    '

# Copy configuration files and scripts using --link for better layer reuse.
COPY --link configs/zshrc /root/.zshrc
COPY --link configs/p10k.zsh /root/.p10k.zsh
COPY --link --chmod=755 tools/transfer.sh /usr/local/bin/transfer.sh

# Set the working directory and default command.
WORKDIR /root
CMD [ "bash", "-c", "zsh; exit 0" ]

# ==============================================================================
# Docker Stage: Installs Docker CLI and related tools
# ==============================================================================
FROM base AS docker

RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    bash -c ' \
    set -eux; \
    \
    # Add Docker''s official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    \
    # Add Docker repository to apt sources list
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null; \
    \
    # Install Docker components
    apt-get update; \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
    '

# ==============================================================================
# Podman Stage: Installs Podman and related tools
# ==============================================================================
FROM base AS podman

# Install Podman and fuse-overlayfs.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    apt-get update && apt-get install -y --no-install-recommends podman fuse-overlayfs && \
    apt-get clean

# Copy Podman storage configuration file.
COPY --link configs/podman-storage.conf /root/.config/containers/storage.conf

# ==============================================================================
# Containerd/nerdctl Stage: Installs nerdctl (full version with containerd)
# ==============================================================================
FROM base AS containerd

ARG TARGETARCH

# Download and install the latest full version of nerdctl, which includes containerd.
# The script verifies the download with a SHA256 checksum.
RUN --mount=type=cache,target=/tmp/nerdctl \
    bash -c ' \
    set -eux; \
    \
    # Detect architecture for GitHub release URL
    case "$TARGETARCH" in \
        amd64) ARCH=amd64 ;; \
        arm64) ARCH=arm64 ;; \
        arm)   ARCH=arm-v7 ;; \
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac; \
    \
    # Fetch the latest release tag from the GitHub API
    TAG=$(curl -s https://api.github.com/repos/containerd/nerdctl/releases/latest | jq -r .tag_name); \
    FILE="nerdctl-full-${TAG#v}-linux-${ARCH}.tar.gz"; \
    URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/${FILE}"; \
    CHECKSUM_URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/SHA256SUMS"; \
    ARCHIVE="/tmp/nerdctl/$FILE"; \
    \
    # Download and verify the archive if not cached
    if [ ! -f "$ARCHIVE" ]; then \
        echo "Downloading $URL"; \
        curl -fsSL "$URL" -o "$ARCHIVE"; \
        curl -fsSL "$CHECKSUM_URL" -o "/tmp/nerdctl/SHA256SUMS"; \
    fi; \
    \
    # Verify checksum
    cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c -; \
    \
    # Extract the archive
    tar Cxzvvf /usr/local "$ARCHIVE"; \
    '

# Copy the entrypoint script for containerd.
COPY --link --chmod=755 entrypoint-containerd.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
