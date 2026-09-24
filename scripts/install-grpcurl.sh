#!/usr/bin/env bash
#
# Download and install grpcurl from GitHub releases with SHA256 verification.
#
# Expected environment variables:
#   TARGETARCH       - Docker build architecture (amd64, arm64)
#   GRPCURL_VERSION  - Optional release tag to install (e.g. v1.9.4 or 1.9.4).
#                      Empty or unset installs the latest release.
#   GITHUB_TOKEN     - Optional, see lib.sh.
#
# This script is run from a bind mount of scripts/ in a Dockerfile RUN
# instruction, with a cache mount on /tmp/grpcurl.

set -euxo pipefail

# shellcheck source-path=SCRIPTDIR source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

REPO="fullstorydev/grpcurl"
CACHE_DIR="/tmp/grpcurl"

# Map TARGETARCH to grpcurl architecture naming
case "${TARGETARCH:-}" in
    amd64) ARCH="x86_64" ;;
    arm64) ARCH="arm64" ;;
    *) die "Unsupported architecture: '${TARGETARCH:-}'" ;;
esac

TAG=$(resolve_version "${GRPCURL_VERSION:-}" "$REPO")
TAG="v${TAG#v}"
VERSION="${TAG#v}"

# Asset and checksum file names both carry the version, so cache entries of
# different releases never collide.
FILE="grpcurl_${VERSION}_linux_${ARCH}.tar.gz"
SUMS="grpcurl_${VERSION}_checksums.txt"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

mkdir -p "$CACHE_DIR"
fetch "${BASE_URL}/${SUMS}" "${CACHE_DIR}/${SUMS}"
fetch "${BASE_URL}/${FILE}" "${CACHE_DIR}/${FILE}"
verify_sha256 "${CACHE_DIR}/${FILE}" "${CACHE_DIR}/${SUMS}" "$FILE"

# Extract into a scratch directory, then install with sane ownership and mode
# (the archive entries are owned by the upstream CI user).
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
tar -xzf "${CACHE_DIR}/${FILE}" -C "$WORK" grpcurl
install -m 0755 "${WORK}/grpcurl" /usr/local/bin/grpcurl

# Verify installation
grpcurl --version
