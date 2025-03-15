#!/usr/bin/env bash

BUILDER=macbook

# Base
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:latest \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target base \
    --push \
    .

# Dockerv
docker buildx build \
    --platform linux/amd64,linux/arm64 
    -t obeoneorg/netshoot:nerdctl \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target nerdctl \
    --push \
    .

# podman
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:podman \
    --cache-from type=registry,ref=private.registry-cache.obeone.org/netshoot:build \
    --cache-to type=registry,ref=private.registry-cache.obeone.org/netshoot:build,mode=max \
    --target podman \
    --push \
    .
