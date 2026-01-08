#!/usr/bin/env bash
#
# Build and Push Script for Netshoot Docker Image
#
# This script manages the multi-platform build and push process for the Netshoot
# Docker image. It supports building specific targets from the Dockerfile,
# managing cache, and tagging images appropriately.
#
# Maintainer: Grégoire Compagnon (obeone) <obeone@obeone.org>
#

set -e

# ------------------------------------------------------------------------------
# Default Configuration
# ------------------------------------------------------------------------------
TARGET_ARG=""
TYPE_ARG=""
USE_CACHE=true
BUILDER="cloud-obeoneorg-cloud"
# BUILDER="multiplatform"
IMAGE_NAME="obeoneorg/netshoot"
# IMAGE_NAME="harbor.obeone.cloud/public/netshoot"
CACHE_IMAGE="obeoneorg/netshoot-cache"
# CACHE_IMAGE="build.registry-cache.obeone.org/public/netshoot"
PLATFORMS="linux/amd64,linux/arm64"
# PLATFORMS="linux/amd64,linux/arm64,linux/386"

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------

# Parse command line arguments.
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   --type=<type> | -y <type>         Build a specific type (debian or slim).
#                                     If not specified, all types are built.
#   --target=<target> | -t <target>   Build a specific target (e.g., base, docker).
#                                     If not specified, all targets for the selected type are built.
#   --builder=<builder> | -b <builder> Specify the Docker buildx builder to use.
#                                     Defaults to "cloud-obeoneorg-cloud".
#   --no-cache                        Disable the use of registry cache.
while [[ $# -gt 0 ]]; do
    case $1 in
        --target=*)
            TARGET_ARG="${1#*=}"
            shift
            ;;
        -t | --target)
            TARGET_ARG="$2"
            shift 2
            ;;
        --type=*)
            TYPE_ARG="${1#*=}"
            shift
            ;;
        -y | --type)
            TYPE_ARG="$2"
            shift 2
            ;;
        --builder=*)
            BUILDER="${1#*=}"
            shift
            ;;
        -b | --builder)
            BUILDER="$2"
            shift 2
            ;;
        --no-cache)
            USE_CACHE=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--type=<type>] [--target=<target>] [--no-cache] [--builder=<builder>]"
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Build Configuration
# ------------------------------------------------------------------------------

# Base arguments for all docker buildx build commands.
BASE_ARGS=(
    --builder "$BUILDER"
    --platform "$PLATFORMS"
    --push
)

# Cache configuration note.
#
# The cache is set per-build inside build_target() so that each build tag uses its
# own cache reference (e.g. $CACHE_IMAGE:<build-tag>). This avoids cache clashes
# between different tags/types/targets.
if [[ "$USE_CACHE" == "true" ]]; then
    echo "INFO: Docker build cache is ENABLED (tagged per build)."
else
    echo "INFO: Docker build cache is DISABLED."
fi

# Add build context.
BASE_ARGS+=(.)

# List of build targets for each type.
declare -A TARGETS
TARGETS["debian"]="
    base:debian-latest,debian,latest
    docker:debian-docker,docker
    podman:debian-podman,podman
    nerdctl:debian-nerdctl,nerdctl
    containerd:debian-containerd,containerd
"
TARGETS["slim"]="
    base:slim-latest,slim
"

# ------------------------------------------------------------------------------
# Build Functions
# ------------------------------------------------------------------------------

# build_target
#
# Builds a specific Docker target with its associated tags.
#
# Arguments:
#   $1 - A string in the format "target:tag1,tag2,..."
#   $2 - The Dockerfile to use for the build.
#
build_target() {
    local entry="$1"
    local dockerfile="$2"
    IFS=':' read -r target tags <<< "$entry"
    IFS=',' read -ra tags_arr <<< "$tags"

    # Use the first tag as the build identifier for cache.
    # Example: for "base:debian-latest,debian,latest" -> cache ref is "$CACHE_IMAGE:debian-latest".
    local build_tag="${tags_arr[0]}"
    if [[ -z "$build_tag" ]]; then
        echo "ERROR: Unable to determine build tag for cache (empty tag list)."
        exit 1
    fi

    local tag_args=()
    for tag in "${tags_arr[@]}"; do
        tag_args+=(-t "${IMAGE_NAME}:$tag")
    done

    local cache_args=()
    if [[ "$USE_CACHE" == "true" ]]; then
        cache_args+=(--cache-from "type=registry,ref=${CACHE_IMAGE}:${build_tag}")
        cache_args+=(--cache-to "type=registry,ref=${CACHE_IMAGE}:${build_tag},mode=max")
    else
        cache_args+=(--no-cache)
    fi

    echo "--------------------------------------------------"
    echo "Building target: $target with tags: ${tags_arr[*]} from $dockerfile"
    if [[ "$USE_CACHE" == "true" ]]; then
        echo "Using cache ref: ${CACHE_IMAGE}:${build_tag}"
    fi
    echo "--------------------------------------------------"

    docker buildx build \
        "${BASE_ARGS[@]}" \
        "${cache_args[@]}" \
        --file "$dockerfile" \
        "${tag_args[@]}" \
        --target "$target"
}

# build_type
#
# Builds all (or a specific) target for a given build type (debian or slim).
#
# Arguments:
#   $1 - The build type (debian or slim).
#
build_type() {
    local type=$1
    local dockerfile=""
    if [[ "$type" == "debian" ]]; then
        dockerfile="Dockerfile"
    elif [[ "$type" == "slim" ]]; then
        dockerfile="Dockerfile.slim"
    else
        echo "ERROR: Unknown build type '$type'."
        exit 1
    fi

    local type_targets=(${TARGETS[$type]})

    if [[ -n "$TARGET_ARG" ]]; then
        # Build a specific target if provided.
        local target_found=false
        for entry in "${type_targets[@]}"; do
            IFS=':' read -r target _ <<< "$entry"
            if [[ "$target" == "$TARGET_ARG" ]]; then
                build_target "$entry" "$dockerfile"
                target_found=true
                break
            fi
        done

        if [[ "$target_found" == false ]]; then
            echo "ERROR: Target '$TARGET_ARG' not found for type '$type'."
            echo "Available targets for type '$type':"
            for entry in "${type_targets[@]}"; do
                IFS=':' read -r target _ <<< "$entry"
                echo "  - $target"
            done
            exit 1
        fi
    else
        # Build all targets for the specified type.
        echo "INFO: Building all targets for type '$type'..."
        for entry in "${type_targets[@]}"; do
            build_target "$entry" "$dockerfile"
        done
    fi
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------

if [[ -n "$TYPE_ARG" ]]; then
    build_type "$TYPE_ARG"
else
    echo "INFO: Building all types..."
    for type in "${!TARGETS[@]}"; do
        build_type "$type"
    done
fi

echo "--------------------------------------------------"
echo "All builds completed successfully."
echo "--------------------------------------------------"
