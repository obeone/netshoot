#!/usr/bin/env bash
set -e

BUILDER=kube-multiplatform

# Base
docker buildx build \
    --builder $BUILDER \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:latest \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target base \
    --push \
    .

# Docker
docker buildx build \
    --builder $BUILDER \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:docker \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target docker \
    --push \
    .

# nerdctl
docker buildx build \
    --builder $BUILDER \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:nerdctl \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target nerdctl \
    --push \
    .

# nerdctl
docker buildx build \
    --builder $BUILDER \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:nerdctl \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target nerdctl \
    --push \
    .

# podman
docker buildx build \
    --builder $BUILDER \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:podman \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target podman \
    --push \
    .
