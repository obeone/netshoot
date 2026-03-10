#!/usr/bin/env bash
#
# Install Oh My Zsh, plugins, Powerlevel10k theme, and gitstatus binary.
#
# Expected environment variables:
#   TARGETARCH  - Docker build architecture (amd64, arm64, etc.)
#
# This script is called from a Dockerfile RUN instruction with a cache mount
# on /root/.cache. The gitstatus binary must be persisted outside that mount
# using GITSTATUS_CACHE_DIR.

set -eux

# Install Oh My Zsh non-interactively
curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | \
    bash -s -- --unattended

# Define the custom plugins and themes directory
ZSH_CUSTOM=/root/.oh-my-zsh/custom

# Clone Zsh plugins and Powerlevel10k theme (depth 1 for speed)
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    ${ZSH_CUSTOM}/plugins/zsh-autosuggestions

git clone --depth 1 https://github.com/zsh-users/zsh-completions \
    ${ZSH_CUSTOM}/plugins/zsh-completions

git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting \
    ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting

git clone --depth 1 https://github.com/romkatv/powerlevel10k.git \
    ${ZSH_CUSTOM}/themes/powerlevel10k

# Install gitstatus for Powerlevel10k.
# GITSTATUS_CACHE_DIR must point outside the cache mount (/root/.cache)
# so the binary is persisted in the image layer.
case "$TARGETARCH" in
    amd64)   PLATFORM="x86_64" ;;
    386)     PLATFORM="i686" ;;
    arm64)   PLATFORM="aarch64" ;;
    arm)     PLATFORM="arm" ;;
    ppc64le) PLATFORM="ppc64le" ;;
    *)       PLATFORM="$TARGETARCH" ;;
esac
GITSTATUS_CACHE_DIR=${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/usrbin \
    ${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/install -s linux -m ${PLATFORM}
