# syntax=docker/dockerfile:1
#
# Netshoot: A powerful Docker image for network troubleshooting and analysis.
#
# This Dockerfile builds a customized Debian Trixie image equipped with a
# comprehensive suite of networking and system tools, multiple container runtimes
# (Docker, Podman, nerdctl), and an enhanced Zsh shell environment with Oh My Zsh.
#
# Maintainer: Grégoire Compagnon (obeone) <obeone@obeone.org>
#

# ==============================================================================
# Base Stage: Debian Trixie with Essential Tools and Shell Enhancements
# ==============================================================================
FROM debian:trixie AS base

ARG TARGETARCH

# Metadata labels
LABEL org.opencontainers.image.authors="Grégoire Compagnon <obeone@obeone.org>"
LABEL org.opencontainers.image.description="Network troubleshooting toolkit with Docker/Podman/nerdctl"
LABEL org.opencontainers.image.source="https://github.com/obeone/netshoot"

# Set environment variables for terminal, locale, and non-interactive apt.
ENV TERM=xterm-kitty \
    LANG=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Configure apt to keep downloaded packages in the cache.
# This leverages BuildKit caching to speed up subsequent builds.
RUN <<EOT
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
EOT

# Upgrade all packages to their latest versions.
# Uses BuildKit cache mounts with sharing=locked for parallel builds safety.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH},sharing=locked \
    <<EOT
    set -eux
    apt-get update
    apt-get full-upgrade -y
EOT

# Install a comprehensive set of essential utilities for networking and system administration.
# Organized by stability: core utilities first, then specialized tools.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH},sharing=locked \
    bash <<'EOT'
    set -eux

    # Core system tools (rarely change)
    CORE_TOOLS=(
        bash
        ca-certificates
        coreutils
        curl
        file
        git
        gnupg
        openssl
        procps
        sudo
        unzip
        util-linux
        vim
        wget
        zip
        zsh
    )

    # System monitoring and utilities
    SYSTEM_TOOLS=(
        btop
        dstat
        fzf
        htop
        iotop
        jq
        kitty-terminfo
        lsof
        magic-wormhole
        ncdu
        nfs-common
        python3-pip
        rsync
        strace
        sysstat
        thefuck
        tmux
    )

    # Networking tools
    NETWORKING_TOOLS=(
        apache2-utils
        arping
        arp-scan
        bind9-utils
        bmon
        bridge-utils
        conntrack
        dnsutils
        ethtool
        fping
        hping3
        httpie
        iftop
        iperf
        iperf3
        iproute2
        ipset
        iptables
        iputils-ping
        ipvsadm
        masscan
        mtr
        net-tools
        netcat-openbsd
        netperf
        nftables
        ngrep
        nload
        nmap
        openssh-client
        socat
        swaks
        tcpdump
        tcptraceroute
        telnet
        termshark
        traceroute
        tshark
        whois
        wireguard-tools
    )

    # Install in order of stability
    apt-get install -y --no-install-recommends \
        "${CORE_TOOLS[@]}" \
        "${SYSTEM_TOOLS[@]}" \
        "${NETWORKING_TOOLS[@]}"
EOT

# Install official Ookla speedtest CLI.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH},sharing=locked \
    <<EOT
    set -eux

    # Add Ookla repository
    curl -fsSL https://packagecloud.io/ookla/speedtest-cli/gpgkey | \
        gpg --dearmor -o /etc/apt/keyrings/speedtest.gpg
    
    echo "deb [signed-by=/etc/apt/keyrings/speedtest.gpg] https://packagecloud.io/ookla/speedtest-cli/debian/ $(. /etc/os-release && echo "$VERSION_CODENAME") main" | \
        tee /etc/apt/sources.list.d/speedtest.list > /dev/null

    # Install speedtest
    apt-get update
    apt-get install -y --no-install-recommends speedtest
EOT

# Install 'uv', a fast Python package installer from Astral.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install 'check-tls' using uv for TLS/SSL certificate checking.
RUN --mount=type=cache,target=/root/.cache \
    uv tool install check-tls

# Install grpcurl from GitHub releases.
COPY scripts/install-grpcurl.sh /tmp/
RUN --mount=type=cache,target=/tmp/grpcurl \
    /tmp/install-grpcurl.sh

# Install Oh My Zsh, plugins, Powerlevel10k theme, and gitstatus binary.
# A cache mount is used to speed up git clone operations during repeated builds.
COPY scripts/install-omz.sh /tmp/
RUN --mount=type=cache,target=/root/.cache \
    /tmp/install-omz.sh

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

ARG TARGETARCH

LABEL org.opencontainers.image.title="netshoot-docker"
LABEL org.opencontainers.image.description="Netshoot with Docker CLI"

RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH},sharing=locked \
    <<EOT
    set -eux

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository to apt sources list
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker components
    apt-get update
    apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
EOT

# ==============================================================================
# Podman Stage: Installs Podman and related tools
# ==============================================================================
FROM base AS podman

ARG TARGETARCH

LABEL org.opencontainers.image.title="netshoot-podman"
LABEL org.opencontainers.image.description="Netshoot with Podman"

# Install Podman and fuse-overlayfs.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH},sharing=locked \
    <<EOT
    set -eux
    apt-get update
    apt-get install -y --no-install-recommends podman fuse-overlayfs
EOT

# Copy Podman storage configuration file.
COPY --link configs/podman-storage.conf /root/.config/containers/storage.conf

# ==============================================================================
# nerdctl Stage: Installs nerdctl (client only version)
# ==============================================================================
FROM base AS nerdctl

ARG TARGETARCH

LABEL org.opencontainers.image.title="netshoot-nerdctl"
LABEL org.opencontainers.image.description="Netshoot with nerdctl (client only)"

# Download and install nerdctl client with SHA256 verification.
COPY scripts/install-nerdctl.sh /tmp/
RUN --mount=type=cache,target=/tmp/nerdctl \
    /tmp/install-nerdctl.sh client

# ==============================================================================
# Containerd/nerdctl Stage: Installs nerdctl (full version with containerd)
# ==============================================================================
FROM base AS containerd

ARG TARGETARCH

LABEL org.opencontainers.image.title="netshoot-containerd"
LABEL org.opencontainers.image.description="Netshoot with nerdctl full (containerd included)"

# Download and install nerdctl full (includes containerd) with SHA256 verification.
COPY scripts/install-nerdctl.sh /tmp/
RUN --mount=type=cache,target=/tmp/nerdctl \
    /tmp/install-nerdctl.sh full

# Copy the entrypoint script for containerd.
COPY --link --chmod=755 entrypoint-containerd.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
