#!/usr/bin/env bash
#
# Download and install grpcurl from GitHub releases.
#
# Expected environment variables:
#   TARGETARCH  - Docker build architecture (amd64, arm64)
#
# This script is called from a Dockerfile RUN instruction with a cache mount
# on /tmp/grpcurl.

set -eux

# Map TARGETARCH to grpcurl architecture naming
case "$TARGETARCH" in
    amd64)   ARCH="x86_64" ;;
    arm64)   ARCH="arm64" ;;
    *)       echo "Unsupported architecture: $TARGETARCH" >&2 && exit 1 ;;
esac

# Fetch the latest release tag from the GitHub API
TAG=$(curl -fsSL https://api.github.com/repos/fullstorydev/grpcurl/releases/latest | jq -r .tag_name)

FILE="grpcurl_${TAG#v}_linux_${ARCH}.tar.gz"
URL="https://github.com/fullstorydev/grpcurl/releases/download/${TAG}/${FILE}"
ARCHIVE="/tmp/grpcurl/${FILE}"

# Download the archive if not cached
if [ ! -f "$ARCHIVE" ]; then
    echo "Downloading grpcurl ${TAG} from $URL"
    curl -fsSL "$URL" -o "$ARCHIVE"
fi

# Extract and install grpcurl binary
tar -xzf "$ARCHIVE" -C /usr/local/bin grpcurl
chmod +x /usr/local/bin/grpcurl

# Verify installation
grpcurl --version
