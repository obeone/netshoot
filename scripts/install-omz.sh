#!/usr/bin/env bash
#
# Install Oh My Zsh, plugins, the Powerlevel10k theme and its gitstatus binary
# into /opt/oh-my-zsh, shared by every user of the image (root or any uid).
#
# Every repository is fetched at a pinned commit instead of running the
# upstream curl | bash installer, so builds are reproducible and a moved branch
# or tag cannot change what lands in the image. No ~/.zshrc is created: the
# shell configuration lives in $ZDOTDIR (see the Dockerfiles).
#
# Expected environment variables:
#   TARGETARCH  - Docker build architecture (amd64, arm64, etc.), used to pick
#                 the gitstatus binary.
#
# This script is run from a bind mount of scripts/ in a Dockerfile RUN
# instruction, with a cache mount on /root/.cache. The gitstatus binary must be
# persisted outside that mount using GITSTATUS_CACHE_DIR.

set -euxo pipefail

# shellcheck source-path=SCRIPTDIR source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

# ------------------------------------------------------------------------------
# Pinned commits.
#
# To bump one, pick the new commit on the upstream default branch (or the
# commit a release tag points to) and replace the SHA below, e.g.:
#
#   git ls-remote https://github.com/ohmyzsh/ohmyzsh.git HEAD
#   git ls-remote https://github.com/romkatv/powerlevel10k.git 'refs/tags/v1.20.0^{}'
#
# Use the peeled "^{}" line for annotated tags: it is the commit, not the tag
# object.
# ------------------------------------------------------------------------------
readonly OMZ_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
readonly OMZ_COMMIT="74965c96098134b192f00084f966b4b02438a739"

readonly AUTOSUGGESTIONS_REPO="https://github.com/zsh-users/zsh-autosuggestions.git"
readonly AUTOSUGGESTIONS_COMMIT="85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"

readonly COMPLETIONS_REPO="https://github.com/zsh-users/zsh-completions.git"
readonly COMPLETIONS_COMMIT="b5e8e0a22deb05a807bb8655aef809a29f3cffed"

readonly FSH_REPO="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
readonly FSH_COMMIT="4672ad5dd9ad68a7effc1476d65afb7c584ce2b3"

# Powerlevel10k v1.20.0
readonly P10K_REPO="https://github.com/romkatv/powerlevel10k.git"
readonly P10K_COMMIT="35833ea15f14b71dbcebc7e54c104d8d56ca5268"

readonly ZSH="/opt/oh-my-zsh"
readonly ZSH_CUSTOM="${ZSH}/custom"

# clone_pinned <repo-url> <commit> <dest>
#
# Shallow-fetch exactly <commit> into <dest> and check it out (detached).
clone_pinned() {
    local url="$1" commit="$2" dest="$3" head

    git init -q "$dest"
    git -C "$dest" remote add origin "$url"
    git -C "$dest" fetch -q --depth 1 origin "$commit"
    git -C "$dest" -c advice.detachedHead=false checkout -q FETCH_HEAD

    head=$(git -C "$dest" rev-parse HEAD)
    [[ "$head" == "$commit" ]] || die "${url}: checked out ${head}, expected ${commit}"
}

clone_pinned "$OMZ_REPO" "$OMZ_COMMIT" "$ZSH"
clone_pinned "$AUTOSUGGESTIONS_REPO" "$AUTOSUGGESTIONS_COMMIT" \
    "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
clone_pinned "$COMPLETIONS_REPO" "$COMPLETIONS_COMMIT" \
    "${ZSH_CUSTOM}/plugins/zsh-completions"
clone_pinned "$FSH_REPO" "$FSH_COMMIT" \
    "${ZSH_CUSTOM}/plugins/fast-syntax-highlighting"
clone_pinned "$P10K_REPO" "$P10K_COMMIT" \
    "${ZSH_CUSTOM}/themes/powerlevel10k"

# Install gitstatus for Powerlevel10k.
# GITSTATUS_CACHE_DIR must point outside the cache mount (/root/.cache)
# so the binary is persisted in the image layer; Powerlevel10k looks for it in
# gitstatus/usrbin first, so no per-user download happens at runtime.
case "${TARGETARCH:-}" in
    amd64)   PLATFORM="x86_64" ;;
    386)     PLATFORM="i686" ;;
    arm64)   PLATFORM="aarch64" ;;
    arm)     PLATFORM="arm" ;;
    ppc64le) PLATFORM="ppc64le" ;;
    "")      die "TARGETARCH is not set" ;;
    *)       PLATFORM="$TARGETARCH" ;;
esac
GITSTATUS_CACHE_DIR="${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/usrbin" \
    "${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/install" -s linux -m "$PLATFORM"

# Owned by root, readable (and directories traversable) by everyone, writable
# by nobody else: zsh's compaudit rejects group/world-writable directories.
chown -R root:root "$ZSH"
chmod -R a+rX,go-w "$ZSH"

# Verify installation
ls "${ZSH_CUSTOM}/themes/powerlevel10k/gitstatus/usrbin/"
git -C "$ZSH" log -1 --format='oh-my-zsh %H %cs'
