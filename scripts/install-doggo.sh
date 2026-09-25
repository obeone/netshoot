#!/usr/bin/env bash
#
# Download and install doggo (DNS client) from GitHub releases with SHA256
# verification. doggo is not packaged for Debian trixie.
#
# Expected environment variables:
#   TARGETARCH     - Docker build architecture (amd64, arm64)
#   DOGGO_VERSION  - Optional release tag to install (e.g. v1.4.0 or 1.4.0).
#                    Empty or unset installs the latest release.
#   GITHUB_TOKEN   - Optional, see lib.sh.
#
# This script is run from a bind mount of scripts/ in a Dockerfile RUN
# instruction, with a cache mount on /tmp/doggo.

set -euxo pipefail

# shellcheck source-path=SCRIPTDIR source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

REPO="mr-karan/doggo"
CACHE_DIR="/tmp/doggo"

# Map TARGETARCH to doggo architecture naming
case "${TARGETARCH:-}" in
    amd64) ARCH="x86_64" ;;
    arm64) ARCH="aarch64" ;;
    *) die "Unsupported architecture: '${TARGETARCH:-}'" ;;
esac

TAG=$(resolve_version "${DOGGO_VERSION:-}" "$REPO")
TAG="v${TAG#v}"
VERSION="${TAG#v}"

# The archive name carries no version (doggo-linux-<arch>.tar.gz), so the
# cached copy is suffixed with the tag. The checksum file is versioned upstream.
FILE="doggo-linux-${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
ARCHIVE="${CACHE_DIR}/doggo-${TAG}-linux-${ARCH}.tar.gz"
SUMS="${CACHE_DIR}/doggo_${VERSION}_checksums.txt"

mkdir -p "$CACHE_DIR"
fetch "${BASE_URL}/doggo_${VERSION}_checksums.txt" "$SUMS"
fetch "${BASE_URL}/${FILE}" "$ARCHIVE"
verify_sha256 "$ARCHIVE" "$SUMS" "$FILE"

# The archive holds doggo, LICENSE and README.md at its root.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
tar -xzf "$ARCHIVE" -C "$WORK" doggo
install -m 0755 "${WORK}/doggo" /usr/local/bin/doggo

# Verify installation
doggo --version
