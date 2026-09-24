#!/usr/bin/env bash
#
# Download and install witr from GitHub releases with SHA256 verification.
#
# witr is not packaged for Debian trixie (it only reaches the archive in
# forky/sid), so the upstream release binary is used instead of an apt package.
#
# Expected environment variables:
#   TARGETARCH    - Docker build architecture (amd64, arm64)
#   WITR_VERSION  - Optional release tag to install (e.g. v0.3.3 or 0.3.3).
#                   Empty or unset installs the latest release.
#   GITHUB_TOKEN  - Optional, see lib.sh.
#
# This script is run from a bind mount of scripts/ in a Dockerfile RUN
# instruction, with a cache mount on /tmp/witr.

set -euxo pipefail

# shellcheck source-path=SCRIPTDIR source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

REPO="pranshuparmar/witr"
CACHE_DIR="/tmp/witr"

# Map TARGETARCH to the witr release asset architecture naming
case "${TARGETARCH:-}" in
    amd64) ARCH=amd64 ;;
    arm64) ARCH=arm64 ;;
    *) die "Unsupported architecture: '${TARGETARCH:-}'" ;;
esac

TAG=$(resolve_version "${WITR_VERSION:-}" "$REPO")
TAG="v${TAG#v}"

# Release assets are raw binaries, not archives: witr-linux-<arch>. Neither
# the asset nor SHA256SUMS carry the version in their name, so the cached
# copies are suffixed with the tag.
FILE="witr-linux-${ARCH}"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
BINARY="${CACHE_DIR}/${FILE}-${TAG}"
SUMS="${CACHE_DIR}/SHA256SUMS-${TAG}"

mkdir -p "$CACHE_DIR"
fetch "${BASE_URL}/SHA256SUMS" "$SUMS"
fetch "${BASE_URL}/${FILE}" "$BINARY"
# Exact name match, so the bare binary cannot pick up the .deb/.rpm/.apk lines.
verify_sha256 "$BINARY" "$SUMS" "$FILE"

# Install the binary under its canonical name
install -m 0755 "$BINARY" /usr/local/bin/witr

# Verify installation
witr --version
