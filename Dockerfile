# syntax=docker/dockerfile:1
#
# Netshoot: A powerful Docker image for network troubleshooting and analysis.
#
# This Dockerfile builds a customized Debian Trixie image equipped with a
# comprehensive suite of networking and system tools, multiple container runtimes
# (Docker, Podman, nerdctl), and an enhanced Zsh shell environment with Oh My Zsh.
#

# ==============================================================================
# Base Stage: Debian Trixie with Essential Tools and Shell Enhancements
# ==============================================================================
FROM debian:trixie AS base

ARG TARGETARCH

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
# Uses BuildKit cache mounts to accelerate the process.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    <<EOT
    apt-get update
    apt-get full-upgrade -y
EOT

# Install a comprehensive set of essential utilities for networking and system administration.
# Uses BuildKit cache mounts for faster installation.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    bash <<'EOT'
    set -eux

    # Define package lists
    NETWORKING_TOOLS=(
        apache2-utils
        bind9-utils
        bird2 
        bridge-utils
        conntrack
        curl
        dhcping
        dnsutils
        ethtool
        fping
        httpie
        iftop
        iperf
        iperf3
        iproute2
        ipset
        iptables
        iputils-ping
        ipvsadm
        mtr
        net-tools
        netcat-openbsd
        nftables
        ngrep
        nmap
        openssh-client
        socat
        speedtest-cli
        swaks
        tcpdump
        tcptraceroute
        telnet
        termshark
        traceroute
        tshark
        wget
        whois
        wireguard-tools
    )

    SYSTEM_TOOLS=(
        bash
        btop
        ca-certificates
        coreutils
        e2fsprogs
        fail2ban
        file
        fzf
        gdisk
        git
        htop
        iotop
        jq
        kitty-terminfo
        logrotate
        lsof
        lynx
        magic-wormhole
        ncdu
        nfs-common
        nmon
        openssl
        procps
        python3-pip
        rsync
        screen
        strace
        sudo
        sysstat
        tmux
        unzip
        util-linux
        vim
        zip
        zsh
    )

    # Install all packages
    apt-get install -y --no-install-recommends "${NETWORKING_TOOLS[@]}" "${SYSTEM_TOOLS[@]}"
EOT

# Install 'uv', a fast Python package installer from Astral.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install 'check-tls' using uv for TLS/SSL certificate checking.
RUN --mount=type=cache,target=/root/.cache uv tool install check-tls

# Install Oh My Zsh, essential plugins, and the Powerlevel10k theme.
# This enhances the shell with auto-suggestions, syntax highlighting, and more.
# A cache mount is used to speed up git clone operations during repeated builds.
RUN --mount=type=cache,target=/root/.cache <<EOT
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

    # Install gitstatus for Powerlevel10k
    case "$TARGETARCH" in
        amd64)   PLATFORM="x86_64" ;;
        386)     PLATFORM="i686" ;;
        arm64)   PLATFORM="aarch64" ;;
        arm)     PLATFORM="arm" ;;
        ppc64le) PLATFORM="ppc64le" ;;
        *)       PLATFORM="$TARGETARCH" ;;
    esac
    ${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/install -s linux -m ${PLATFORM}
EOT

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

RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    <<EOT
    set -eux

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository to apt sources list
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker components
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
EOT

# ==============================================================================
# Podman Stage: Installs Podman and related tools
# ==============================================================================
FROM base AS podman

# Install Podman and fuse-overlayfs.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-${TARGETARCH} \
    --mount=type=cache,target=/var/lib/apt,id=apt-${TARGETARCH} \
    <<EOT
    apt-get update
    apt-get install -y --no-install-recommends podman fuse-overlayfs
EOT

# Copy Podman storage configuration file.
COPY --link configs/podman-storage.conf /root/.config/containers/storage.conf

# ==============================================================================
# nerdctl Base Stage: Common nerdctl installation logic
# ==============================================================================
FROM base AS nerdctl-base

ARG TARGETARCH
ARG NERDCTL_VARIANT=""

# Download and install nerdctl.
# The script verifies the download with a SHA256 checksum.
RUN --mount=type=cache,target=/tmp/nerdctl <<EOT
    set -eux

    # Detect architecture for GitHub release URL
    case "$TARGETARCH" in
        amd64) ARCH=amd64 ;;
        arm64) ARCH=arm64 ;;
        arm)   ARCH=arm-v7 ;;
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;;
    esac

    # Fetch the latest release tag from the GitHub API
    TAG=$(curl -s https://api.github.com/repos/containerd/nerdctl/releases/latest | jq -r .tag_name)

    # Determine filename based on variant
    if [ "$NERDCTL_VARIANT" = "full" ]; then
        FILE="nerdctl-full-${TAG#v}-linux-${ARCH}.tar.gz"
    else
        FILE="nerdctl-${TAG#v}-linux-${ARCH}.tar.gz"
    fi

    URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/${FILE}"
    CHECKSUM_URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/SHA256SUMS"
    ARCHIVE="/tmp/nerdctl/$FILE"

    # Download and verify the archive if not cached
    if [ ! -f "$ARCHIVE" ]; then
        echo "Downloading $URL"
        curl -fsSL "$URL" -o "$ARCHIVE"
        curl -fsSL "$CHECKSUM_URL" -o "/tmp/nerdctl/SHA256SUMS"
    fi

    # Verify checksum - ensure the file exists in SHA256SUMS
    if ! grep -q "$FILE" /tmp/nerdctl/SHA256SUMS; then
        echo "ERROR: Checksum for $FILE not found in SHA256SUMS" >&2
        exit 1
    fi
    cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c -

    # Extract the archive
    tar Cxzvvf /usr/local "$ARCHIVE"
EOT

# ==============================================================================
# nerdctl Stage: Installs nerdctl (client only version)
# ==============================================================================
FROM nerdctl-base AS nerdctl

ARG NERDCTL_VARIANT=""

# ==============================================================================
# Containerd/nerdctl Stage: Installs nerdctl (full version with containerd)
# ==============================================================================
FROM nerdctl-base AS containerd

ARG NERDCTL_VARIANT="full"

# Copy the entrypoint script for containerd.
COPY --link --chmod=755 entrypoint-containerd.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
