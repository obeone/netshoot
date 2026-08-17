#!/usr/bin/env bash
#
# Download and install witr from GitHub releases with SHA256 verification.
#
# witr is not packaged for Debian trixie (it only reaches the archive in
# forky/sid), so the upstream release binary is used instead of an apt package.
#
# Expected environment variables:
#   TARGETARCH  - Docker build architecture (amd64, arm64)
#
# This script is called from a Dockerfile RUN instruction with a cache mount
# on /tmp/witr.

set -eux

# Map TARGETARCH to the witr release asset architecture naming
case "$TARGETARCH" in
    amd64) ARCH=amd64 ;;
    arm64) ARCH=arm64 ;;
    *) echo "Unsupported architecture: $TARGETARCH" >&2 && exit 1 ;;
esac

# Fetch the latest release tag from the GitHub API
TAG=$(curl -fsSL https://api.github.com/repos/pranshuparmar/witr/releases/latest | \
    jq -r .tag_name)

# Release assets are raw binaries, not archives: witr-linux-<arch>
FILE="witr-linux-${ARCH}"
URL="https://github.com/pranshuparmar/witr/releases/download/${TAG}/${FILE}"
CHECKSUM_URL="https://github.com/pranshuparmar/witr/releases/download/${TAG}/SHA256SUMS"
BINARY="/tmp/witr/$FILE"

# Download the binary and checksums if not cached
if [ ! -f "$BINARY" ]; then
    echo "Downloading witr ${TAG} from $URL"
    curl -fsSL "$URL" -o "$BINARY"
    curl -fsSL "$CHECKSUM_URL" -o "/tmp/witr/SHA256SUMS"
fi

# Verify checksum. The pattern is anchored on the line end so that the bare
# binary name cannot match the packaged assets (.deb, .rpm, .apk).
if ! grep -q " ${FILE}\$" /tmp/witr/SHA256SUMS; then
    echo "ERROR: Checksum for $FILE not found in SHA256SUMS" >&2
    exit 1
fi
cd /tmp/witr && grep " ${FILE}\$" SHA256SUMS | sha256sum -c -

# Install the binary under its canonical name
install -m 0755 "$BINARY" /usr/local/bin/witr

# Verify installation
witr --version
