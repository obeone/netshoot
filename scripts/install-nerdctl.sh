#!/usr/bin/env bash
#
# Download and install nerdctl from GitHub releases with SHA256 verification.
#
# Usage:
#   install-nerdctl.sh client   # nerdctl client only
#   install-nerdctl.sh full     # nerdctl-full (includes containerd)
#
# Expected environment variables:
#   TARGETARCH  - Docker build architecture (amd64, arm64, arm)
#
# This script is called from a Dockerfile RUN instruction with a cache mount
# on /tmp/nerdctl.

set -eux

VARIANT="${1:?Usage: install-nerdctl.sh <client|full>}"

# Detect architecture for GitHub release URL
case "$TARGETARCH" in
    amd64) ARCH=amd64 ;;
    arm64) ARCH=arm64 ;;
    arm)   ARCH=arm-v7 ;;
    *) echo "Unsupported architecture: $TARGETARCH" >&2 && exit 1 ;;
esac

# Determine filename prefix based on variant
case "$VARIANT" in
    client) PREFIX="nerdctl" ;;
    full)   PREFIX="nerdctl-full" ;;
    *) echo "Unknown variant: $VARIANT (expected 'client' or 'full')" >&2 && exit 1 ;;
esac

# Fetch the latest release tag from the GitHub API
TAG=$(curl -fsSL https://api.github.com/repos/containerd/nerdctl/releases/latest | \
    jq -r .tag_name)

FILE="${PREFIX}-${TAG#v}-linux-${ARCH}.tar.gz"
URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/${FILE}"
CHECKSUM_URL="https://github.com/containerd/nerdctl/releases/download/${TAG}/SHA256SUMS"
ARCHIVE="/tmp/nerdctl/$FILE"

# Download the archive and checksums if not cached
if [ ! -f "$ARCHIVE" ]; then
    echo "Downloading ${PREFIX} ${TAG} from $URL"
    curl -fsSL "$URL" -o "$ARCHIVE"
    curl -fsSL "$CHECKSUM_URL" -o "/tmp/nerdctl/SHA256SUMS"
fi

# Verify checksum
if ! grep -q "$FILE" /tmp/nerdctl/SHA256SUMS; then
    echo "ERROR: Checksum for $FILE not found in SHA256SUMS" >&2
    exit 1
fi
cd /tmp/nerdctl && grep "$FILE" SHA256SUMS | sha256sum -c -

# Extract the archive
tar Cxzvf /usr/local "$ARCHIVE"
