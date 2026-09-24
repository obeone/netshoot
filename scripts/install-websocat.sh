#!/usr/bin/env bash
#
# Download and install websocat (WebSocket client) from GitHub releases.
# websocat is not packaged for Debian trixie.
#
# Upstream publishes no checksum file for its release assets, so the download
# cannot be verified against a published hash: it relies on HTTPS to GitHub
# and on the final version check below.
#
# Expected environment variables:
#   TARGETARCH        - Docker build architecture (amd64, arm64)
#   WEBSOCAT_VERSION  - Optional release tag to install (e.g. v1.14.1 or
#                       1.14.1). Empty or unset installs the latest release.
#   GITHUB_TOKEN      - Optional, see lib.sh.
#
# This script is run from a bind mount of scripts/ in a Dockerfile RUN
# instruction, with a cache mount on /tmp/websocat.

set -euxo pipefail

# shellcheck source-path=SCRIPTDIR source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

REPO="vi/websocat"
CACHE_DIR="/tmp/websocat"

# Map TARGETARCH to the Rust target triple used by the release assets
# (statically linked musl builds).
case "${TARGETARCH:-}" in
    amd64) ARCH="x86_64" ;;
    arm64) ARCH="aarch64" ;;
    *) die "Unsupported architecture: '${TARGETARCH:-}'" ;;
esac

TAG=$(resolve_version "${WEBSOCAT_VERSION:-}" "$REPO")
TAG="v${TAG#v}"
VERSION="${TAG#v}"

# Release assets are raw binaries without a version in their name, so the
# cached copy is suffixed with the tag.
FILE="websocat.${ARCH}-unknown-linux-musl"
BINARY="${CACHE_DIR}/${FILE}-${TAG}"

mkdir -p "$CACHE_DIR"
fetch "https://github.com/${REPO}/releases/download/${TAG}/${FILE}" "$BINARY"

install -m 0755 "$BINARY" /usr/local/bin/websocat

# Verify installation: the binary runs and reports the requested version.
# A bad cache entry is dropped so the next build downloads it again.
REPORTED=$(websocat --version) || REPORTED=""
if [[ "$REPORTED" != "websocat ${VERSION}" ]]; then
    rm -f "$BINARY" /usr/local/bin/websocat
    die "websocat --version reports '${REPORTED}', expected 'websocat ${VERSION}'"
fi
