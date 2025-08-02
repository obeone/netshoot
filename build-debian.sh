#!/usr/bin/env bash
#
# Build and Push Script for Netshoot Docker Image
#
# This script manages the multi-platform build and push process for the Netshoot
# Docker image. It supports building specific targets from the Dockerfile,
# managing cache, and tagging images appropriately.
#
# Usage:
#   ./build-debian.sh [OPTIONS]
#
# Options:
#   --target=<target> | -t <target>   Build a specific target (e.g., base, docker).
#                                     If not specified, all targets are built.
#   --builder=<builder> | -b <builder> Specify the Docker buildx builder to use.
#                                     Defaults to "multiplatform".
#   --no-cache                        Disable the use of registry cache.
#

set -e

# ------------------------------------------------------------------------------
# Default Configuration
# ------------------------------------------------------------------------------
TARGET_ARG=""
USE_CACHE=true
BUILDER="multiplatform"
# IMAGE_NAME="obeoneorg/netshoot"
IMAGE_NAME="harbor.obeone.cloud/public/netshoot"
CACHE_IMAGE="build.registry-cache.obeone.org/public/netshoot"
PLATFORMS="linux/amd64,linux/arm64"
# PLATFORMS="linux/amd64,linux/arm64,linux/386"
DOCKERFILE="Dockerfile"

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --target=*)
      TARGET_ARG="${1#*=}"
      shift
      ;;
    -t|--target)
      TARGET_ARG="$2"
      shift 2
      ;;
    --builder=*)
      BUILDER="${1#*=}"
      shift
      ;;
    -b|--builder)
      BUILDER="$2"
      shift 2
      ;;
    --no-cache)
      USE_CACHE=false
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--target=<target-name>] [--no-cache] [--builder=<builder-name>]"
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Build Configuration
# ------------------------------------------------------------------------------

# Common arguments for all docker buildx build commands.
COMMON_ARGS=(
    --builder "$BUILDER"
    --platform "$PLATFORMS"
    --file "$DOCKERFILE"
    --push
)

# Add cache arguments if enabled.
if [[ "$USE_CACHE" == "true" ]]; then
    echo "INFO: Docker build cache is ENABLED."
    COMMON_ARGS+=(--cache-from "type=registry,ref=$CACHE_IMAGE")
    COMMON_ARGS+=(--cache-to "type=registry,ref=$CACHE_IMAGE,mode=max")
else
    echo "INFO: Docker build cache is DISABLED."
fi

# Add build context.
COMMON_ARGS+=(.)

# List of build targets and their associated tags.
# Each entry is formatted as: "target:tag1,tag2,..."
declare -a TARGETS=(
    "base:debian-latest,debian,latest"
    "docker:debian-docker,docker"
    "podman:debian-podman,podman"
    "nerdctl:debian-nerdctl,nerdctl"
    "containerd:debian-containerd,containerd"
)

# ------------------------------------------------------------------------------
# Build Functions
# ------------------------------------------------------------------------------

# build_target
#
# Builds a specific Docker target with its associated tags.
#
# Arguments:
#   $1 - A string in the format "target:tag1,tag2,..."
#
build_target() {
    local entry="$1"
    IFS=':' read -r target tags <<< "$entry"
    IFS=',' read -ra tags_arr <<< "$tags"
    
    local tag_args=()
    for tag in "${tags_arr[@]}"; do
        tag_args+=(-t "${IMAGE_NAME}:$tag")
    done

    echo "--------------------------------------------------"
    echo "Building target: $target with tags: ${tags_arr[*]}"
    echo "--------------------------------------------------"

    docker buildx build \
        "${COMMON_ARGS[@]}" \
        "${tag_args[@]}" \
        --target "$target"
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------

if [[ -n "$TARGET_ARG" ]]; then
    # Build a specific target if provided.
    target_found=false
    for entry in "${TARGETS[@]}"; do
        IFS=':' read -r target _ <<< "$entry"
        if [[ "$target" == "$TARGET_ARG" ]]; then
            build_target "$entry"
            target_found=true
            break
        fi
    done

    if [[ "$target_found" == false ]]; then
        echo "ERROR: Target '$TARGET_ARG' not found."
        echo "Available targets:"
        for entry in "${TARGETS[@]}"; do
            IFS=':' read -r target _ <<< "$entry"
            echo "  - $target"
        done
        exit 1
    fi
else
    # Build all targets if no specific target is provided.
    echo "INFO: Building all targets..."
    for entry in "${TARGETS[@]}"; do
        build_target "$entry"
    done
fi

echo "--------------------------------------------------"
echo "All builds completed successfully."
echo "--------------------------------------------------"
