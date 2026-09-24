# syntax=docker/dockerfile:1
#
# Netshoot: A powerful Docker image for network troubleshooting and analysis.
#
# This Dockerfile builds a customized Debian Trixie image equipped with a
# comprehensive suite of networking and system tools, container tooling
# (Docker CLI, Podman, nerdctl, containerd), and an enhanced Zsh shell environment
# with Oh My Zsh.
#
# Maintainer: Grégoire Compagnon (obeone) <obeone@obeone.org>
#

# ==============================================================================
# uv Stage: pinned source for the 'uv' binaries
# ==============================================================================
# Declared as a named stage (rather than COPY --from=<image>) so that
# Dependabot can see and bump both the tag and the digest.
FROM ghcr.io/astral-sh/uv:0.12.18@sha256:3adc3706091ce7c2fe595e669628caedd6d951551b92b258b7e7dbe06d9440bc AS uv

# ==============================================================================
# Base Stage: Debian Trixie with Essential Tools and Shell Enhancements
# ==============================================================================
# The tag is kept next to the digest so Dependabot can bump the digest.
FROM debian:trixie@sha256:9cc080028c43b27d2074d63a5f9caf7166d731494965616c1a6d2827a004585c AS base

ARG TARGETARCH

# Metadata labels
LABEL org.opencontainers.image.authors="Grégoire Compagnon <obeone@obeone.org>"
LABEL org.opencontainers.image.description="Network troubleshooting toolkit with Docker/Podman/nerdctl"
LABEL org.opencontainers.image.source="https://github.com/obeone/netshoot"

# Set environment variables for terminal, locale, and non-interactive apt.
# C.UTF-8 is the only UTF-8 locale built into Debian (no locales package), so
# tools such as man do not complain that the locale cannot be set.
ENV TERM=xterm-kitty \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# Run build steps with bash and pipefail, so a failing command in a pipe
# (e.g. curl | gpg) fails the build instead of being masked.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Configure apt to keep downloaded packages in the cache.
# This leverages BuildKit caching to speed up subsequent builds.
RUN <<EOT
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
EOT

# Upgrade all packages to their latest versions.
# Uses BuildKit cache mounts with sharing=locked for parallel builds safety.
# CACHE_BUST (the ISO week, passed by CI and build.sh) invalidates this layer
# and everything after it, so a weekly rebuild picks up security updates.
ARG CACHE_BUST=
RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-lists-${TARGETARCH},sharing=locked \
    <<EOT
    set -eux
    echo "cache bust: ${CACHE_BUST}"
    apt-get update
    apt-get full-upgrade -y
EOT

# Install a comprehensive set of essential utilities for networking and system administration.
# Organized by stability: core utilities first, then specialized tools.
RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-lists-${TARGETARCH},sharing=locked \
    bash <<'EOT'
    set -eux

    # Make sure man pages are not excluded by a dpkg path-exclude rule, so that
    # man-db has something to index. The pinned debian:trixie image ships no such
    # rule today: this is a no-op guard in case a future digest adds one.
    sed -i '\|^path-exclude=/usr/share/man|d' /etc/dpkg/dpkg.cfg.d/*

    # Core system tools (rarely change)
    CORE_TOOLS=(
        bash
        ca-certificates
        coreutils
        curl
        file
        git
        gnupg
        less
        man-db
        openssl
        procps
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
        fzf
        htop
        iotop
        jq
        kitty-terminfo
        lsof
        magic-wormhole
        ncdu
        python3-venv
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
        bind9-dnsutils
        bmon
        bridge-utils
        conntrack
        dhcpdump
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
        iputils-tracepath
        ipvsadm
        ldap-utils
        masscan
        mtr
        net-tools
        netcat-openbsd
        nethogs
        netperf
        nftables
        ngrep
        nload
        nmap
        openssh-client
        sipcalc
        snmp
        socat
        sslscan
        swaks
        tcpdump
        tcpflow
        tcptraceroute
        telnet
        termshark
        traceroute
        tshark
        whois
        wireguard-tools
    )

    # Install in order of stability
    # Refresh the lists: a cache hit on the upgrade layer does not bring its
    # cache mount along (CI runners start with an empty one), so the lists may
    # be missing or stale here.
    apt-get update
    apt-get install -y --no-install-recommends \
        "${CORE_TOOLS[@]}" \
        "${SYSTEM_TOOLS[@]}" \
        "${NETWORKING_TOOLS[@]}"
EOT

# Install official Ookla speedtest CLI.
# Package versions follow the weekly rebuild, not pins.
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-lists-${TARGETARCH},sharing=locked \
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

# Install 'uv', a fast Python package installer from Astral (pinned in the uv stage).
COPY --from=uv /uv /uvx /usr/local/bin/

# Install 'check-tls' using uv for TLS/SSL certificate checking.
# The tool venv lives in /opt/uv/tools and its entry point in /usr/local/bin, so
# it is usable by any uid (not only root, whose home is not world-readable).
# Only the system Python is used, so the venv never points into /root.
RUN --mount=type=cache,target=/root/.cache \
    UV_TOOL_DIR=/opt/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_PYTHON_PREFERENCE=only-system \
    UV_LINK_MODE=copy \
    uv tool install check-tls

# Tools downloaded from GitHub releases (or dl.k8s.io for kubectl).
# The install scripts are bind-mounted rather than copied, so they never end up
# in the image. Each *_VERSION build arg pins a release (e.g. v1.9.4), empty
# means latest. The optional github_token secret is used for GitHub API calls;
# without it, the scripts resolve the latest tag from the releases/latest redirect.
# Download caches are per architecture so amd64 and arm64 builds never share a file.

# Install grpcurl from GitHub releases (SHA256 verified).
ARG GRPCURL_VERSION=
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/tmp/grpcurl,id=grpcurl-${TARGETARCH} \
    --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    bash /tmp/scripts/install-grpcurl.sh

# Install witr from GitHub releases (no Debian trixie package available, SHA256 verified).
ARG WITR_VERSION=
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/tmp/witr,id=witr-${TARGETARCH} \
    --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    bash /tmp/scripts/install-witr.sh

# Install doggo, a modern DNS client, from GitHub releases (not in trixie, SHA256 verified).
ARG DOGGO_VERSION=
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/tmp/doggo,id=doggo-${TARGETARCH} \
    --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    bash /tmp/scripts/install-doggo.sh

# Install websocat, a WebSocket client, from GitHub releases (not in trixie).
# Upstream publishes no checksums, so only the installed version is checked.
ARG WEBSOCAT_VERSION=
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/tmp/websocat,id=websocat-${TARGETARCH} \
    --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    bash /tmp/scripts/install-websocat.sh

# Install kubectl from dl.k8s.io (trixie ships 1.32, too old; SHA256 verified).
ARG KUBECTL_VERSION=
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/tmp/kubectl,id=kubectl-${TARGETARCH} \
    --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    bash /tmp/scripts/install-kubectl.sh

# Install Oh My Zsh, plugins, Powerlevel10k theme, and gitstatus binary into
# /opt/oh-my-zsh, each at a pinned commit (see scripts/install-omz.sh).
# A cache mount is used to speed up repeated builds.
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/root/.cache \
    bash /tmp/scripts/install-omz.sh

# Shell configuration lives in ZDOTDIR, outside /root, so it works for root and
# for any uid (docker run --user 1000:1000, where HOME=/ is not writable).
# A user who mounts their own ~/.zshrc still gets it: the bundled .zshrc sources
# it instead (see configs/zshrc). skip_global_compinit keeps a global zshrc from
# running compinit before oh-my-zsh does (Debian's only does so on Ubuntu, the
# flag keeps it that way). A user's own ~/.zshenv, ~/.zprofile, ~/.zlogin and
# ~/.zlogout, if any, are still sourced.
ENV ZDOTDIR=/etc/zsh/netshoot
# hadolint ignore=SC2016
RUN <<'EOT'
    set -eux
    mkdir -p /etc/zsh/netshoot
    printf '%s\n' \
        '# Netshoot zshenv (ZDOTDIR=/etc/zsh/netshoot), generated by the Dockerfile.' \
        'skip_global_compinit=1' \
        'if [[ -f "$HOME/.zshenv" && ! "$HOME/.zshenv" -ef "${(%):-%x}" ]]; then' \
        '  source "$HOME/.zshenv"' \
        'fi' \
        > /etc/zsh/netshoot/.zshenv
    # With ZDOTDIR set, zsh would never read ~/.zprofile, ~/.zlogin or
    # ~/.zlogout: forward to them, as the old layout (no ZDOTDIR) did.
    for f in zprofile zlogin zlogout; do
        printf '%s\n' \
            "# Netshoot .${f} (ZDOTDIR=/etc/zsh/netshoot), generated by the Dockerfile." \
            "if [[ -f \"\$HOME/.${f}\" && ! \"\$HOME/.${f}\" -ef \"\${(%):-%x}\" ]]; then" \
            "  source \"\$HOME/.${f}\"" \
            'fi' \
            > "/etc/zsh/netshoot/.${f}"
    done
    chmod 644 /etc/zsh/netshoot/.zshenv /etc/zsh/netshoot/.zprofile \
        /etc/zsh/netshoot/.zlogin /etc/zsh/netshoot/.zlogout
EOT

# Copy configuration files and scripts using --link for better layer reuse.
COPY --link configs/zshrc /etc/zsh/netshoot/.zshrc
COPY --link configs/p10k.zsh /etc/zsh/netshoot/.p10k.zsh
COPY --link --chmod=755 tools/transfer.sh /usr/local/bin/transfer.sh

# Set the working directory and default command.
WORKDIR /root
CMD ["zsh"]

# ==============================================================================
# Docker Stage: Installs Docker CLI and related tools
# ==============================================================================
# CLI only: no daemon (dockerd) and no containerd. Talk to the host engine by
# mounting its socket: -v /var/run/docker.sock:/var/run/docker.sock
FROM base AS docker

ARG TARGETARCH

LABEL org.opencontainers.image.title="netshoot-docker"
LABEL org.opencontainers.image.description="Netshoot with Docker CLI, buildx and compose (mount the host Docker socket)"

# Package versions follow the weekly rebuild, not pins. SHELL (bash with
# pipefail) is inherited from the base stage.
# hadolint ignore=DL3008,DL4006
RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-lists-${TARGETARCH},sharing=locked \
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

    # Install the Docker CLI and its plugins (no engine)
    apt-get update
    apt-get install -y --no-install-recommends \
        docker-buildx-plugin \
        docker-ce-cli \
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
# Package versions follow the base image and the weekly rebuild, not pins.
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-${TARGETARCH},sharing=locked \
    --mount=type=cache,target=/var/lib/apt,id=apt-lists-${TARGETARCH},sharing=locked \
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
# NERDCTL_VERSION pins a release (e.g. v2.4.0), empty means latest.
ARG NERDCTL_VERSION=
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/tmp/nerdctl,id=nerdctl-${TARGETARCH} \
    --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    bash /tmp/scripts/install-nerdctl.sh client

# ==============================================================================
# Containerd/nerdctl Stage: Installs nerdctl (full version with containerd)
# ==============================================================================
FROM base AS containerd

ARG TARGETARCH

LABEL org.opencontainers.image.title="netshoot-containerd"
LABEL org.opencontainers.image.description="Netshoot with nerdctl full (containerd included)"

# Download and install nerdctl full (includes containerd) with SHA256 verification.
# NERDCTL_VERSION pins a release (e.g. v2.4.0), empty means latest.
ARG NERDCTL_VERSION=
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    --mount=type=cache,target=/tmp/nerdctl,id=nerdctl-${TARGETARCH} \
    --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    bash /tmp/scripts/install-nerdctl.sh full

# Copy the entrypoint script for containerd.
COPY --link --chmod=755 entrypoint-containerd.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
