#!/usr/bin/env bash
#
# Download and install kubectl from the upstream Kubernetes release bucket
# (dl.k8s.io) with SHA256 verification. Debian trixie ships kubectl 1.32,
# which is too old to talk to current clusters (kubectl supports +/-1 minor).
#
# Expected environment variables:
#   TARGETARCH       - Docker build architecture (amd64, arm64)
#   KUBECTL_VERSION  - Optional release tag to install (e.g. v1.37.1 or
#                      1.37.1). Empty or unset installs the current stable
#                      release, read from https://dl.k8s.io/release/stable.txt.
#
# This script is run from a bind mount of scripts/ in a Dockerfile RUN
# instruction, with a cache mount on /tmp/kubectl.

set -euxo pipefail

# shellcheck source-path=SCRIPTDIR source=lib.sh disable=SC1091
. "$(dirname "$0")/lib.sh"

CACHE_DIR="/tmp/kubectl"
RELEASE_URL="https://dl.k8s.io/release"

case "${TARGETARCH:-}" in
    amd64) ARCH=amd64 ;;
    arm64) ARCH=arm64 ;;
    *) die "Unsupported architecture: '${TARGETARCH:-}'" ;;
esac

if [[ -n "${KUBECTL_VERSION:-}" ]]; then
    TAG="$KUBECTL_VERSION"
else
    # stable.txt moves with every release, so it is never cached.
    TAG=$(curl -fsSL --retry 3 --retry-connrefused "${RELEASE_URL}/stable.txt")
fi
TAG="v${TAG#v}"
looks_like_tag "$TAG" || die "invalid kubectl version: '${TAG}'"

BASE_URL="${RELEASE_URL}/${TAG}/bin/linux/${ARCH}"
BINARY="${CACHE_DIR}/kubectl-${TAG}-linux-${ARCH}"
SUMS="${BINARY}.sha256"

mkdir -p "$CACHE_DIR"
fetch "${BASE_URL}/kubectl.sha256" "$SUMS"
fetch "${BASE_URL}/kubectl" "$BINARY"
# The .sha256 file holds only the hex digest, without a file name.
verify_sha256_hash "$BINARY" "$(tr -d '[:space:]' < "$SUMS")"

install -m 0755 "$BINARY" /usr/local/bin/kubectl

# Verify installation
kubectl version --client
