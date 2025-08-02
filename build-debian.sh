#!/usr/bin/env bash
set -e

# Parse command line arguments for target specification
TARGET_ARG=""
USE_CACHE=true
BUILDER="multiplatform"
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

# Constants for image name, cache image, platforms, and Dockerfile
# IMAGE_NAME="obeoneorg/netshoot"
IMAGE_NAME="harbor.obeone.cloud/public/netshoot"
CACHE_IMAGE="build.registry-cache.obeone.org/public/netshoot"
PLATFORMS="linux/amd64,linux/arm64"
# PLATFORMS="linux/amd64,linux/arm64,linux/386"
DOCKERFILE="Dockerfile"

# Common arguments for all docker buildx build commands
COMMON_ARGS=(
    --builder "$BUILDER"
    --platform "$PLATFORMS"
    --file "$DOCKERFILE"
    --push
)

# Add cache arguments if enabled
if [[ "$USE_CACHE" == "true" ]]; then
    echo "Cache is enabled."
    COMMON_ARGS+=(--cache-from "type=registry,ref=$CACHE_IMAGE")
    COMMON_ARGS+=(--cache-to "type=registry,ref=$CACHE_IMAGE,mode=max")
else
    echo "Cache is disabled."
fi

COMMON_ARGS+=(.)

# List of build targets and their associated tags
# Each entry is formatted as: target:tag1,tag2,...
# We explicitly list the tags with and without the 'debian-' prefix
# to maintain clarity and simplify the build script logic.
declare -a TARGETS=(
    "base:debian-latest,debian,latest"
    "docker:debian-docker,docker"
    "podman:debian-podman,podman"
    "nerdctl:debian-nerdctl,nerdctl"
    "containerd:debian-containerd,containerd"
)

# Function to build a specific target with its tags
build_target() {
    local entry="$1"
    # Split the entry into target and tags parts
    IFS=':' read -r target tags <<< "$entry"
    # Split tags by comma into an array
    IFS=',' read -ra tags_arr <<< "$tags"
    tag_args=()
    # Prepare -t arguments for each tag
    for tag in "${tags_arr[@]}"; do
        tag_args+=(-t "${IMAGE_NAME}:$tag")
    done

    echo "Building target: $target with tags: ${tags_arr[*]}"

    # Run the docker buildx build command for this target and its tags
    docker buildx build \
        "${COMMON_ARGS[@]}" \
        "${tag_args[@]}" \
        --target "$target"
}

# If a specific target was provided, build only that target
if [[ -n "$TARGET_ARG" ]]; then
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
        echo "Error: Target '$TARGET_ARG' not found in available targets."
        echo "Available targets:"
        for entry in "${TARGETS[@]}"; do
            IFS=':' read -r target _ <<< "$entry"
            echo "  - $target"
        done
        exit 1
    fi
else
    # No target specified, build all targets
    echo "Building all targets..."
    for entry in "${TARGETS[@]}"; do
        build_target "$entry"
    done
fi
