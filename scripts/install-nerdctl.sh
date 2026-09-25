#!/usr/bin/env bash
#
# Download and install nerdctl from GitHub releases with SHA256 verification.
#
# Usage:
#   install-nerdctl.sh client   # nerdctl client only
#   install-nerdctl.sh full     # nerdctl-full (includes containerd)
#
# Expected environment variables:
#   TARGETARCH       - Docker build architecture (amd64, arm64, arm)
#   NERDCTL_VERSION  - Optional release tag to install (e.g. v2.4.0 or 2.4.0).
#                      Empty or unset installs the latest release.
#   GITHUB_TOKEN     - Optional, see lib.sh.
#
# This script is run from a bind mount of scripts/ in a Dockerfile RUN
# instruction, with a cache mount on /tmp/nerdctl.

set -euxo pipefail

# shellcheck source-path=SCRIPTDIR source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

REPO="containerd/nerdctl"
CACHE_DIR="/tmp/nerdctl"
VARIANT="${1:?Usage: install-nerdctl.sh <client|full>}"

# Detect architecture for GitHub release URL
case "${TARGETARCH:-}" in
    amd64) ARCH=amd64 ;;
    arm64) ARCH=arm64 ;;
    arm)   ARCH=arm-v7 ;;
    *) die "Unsupported architecture: '${TARGETARCH:-}'" ;;
esac

# Determine filename prefix based on variant
case "$VARIANT" in
    client) PREFIX="nerdctl" ;;
    full)   PREFIX="nerdctl-full" ;;
    *) die "Unknown variant: $VARIANT (expected 'client' or 'full')" ;;
esac

TAG=$(resolve_version "${NERDCTL_VERSION:-}" "$REPO")
TAG="v${TAG#v}"

FILE="${PREFIX}-${TAG#v}-linux-${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
ARCHIVE="${CACHE_DIR}/${FILE}"
# SHA256SUMS is not versioned upstream: suffix the cached copy with the tag.
SUMS="${CACHE_DIR}/SHA256SUMS-${TAG}"

mkdir -p "$CACHE_DIR"
fetch "${BASE_URL}/SHA256SUMS" "$SUMS"
fetch "${BASE_URL}/${FILE}" "$ARCHIVE"
verify_sha256 "$ARCHIVE" "$SUMS" "$FILE"

# The two archives are laid out differently:
#   client: nerdctl and the containerd-rootless*.sh helpers at the archive
#           root, so they go to /usr/local/bin (extracting into /usr/local
#           would leave nerdctl off the PATH).
#   full:   a /usr/local-style tree (bin/, lib/, libexec/, share/ ...).
# Files are owned by root regardless of the ownership recorded in the archive.
case "$VARIANT" in
    client) DEST=/usr/local/bin ;;
    full)   DEST=/usr/local ;;
esac
tar -xzf "$ARCHIVE" -C "$DEST" --no-same-owner

# Verify installation
nerdctl --version
if [[ "$VARIANT" == "full" ]]; then
    containerd --version
fi
