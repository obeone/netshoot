#!/usr/bin/env bash
set -e

# Base
docker buildx build \
    --builder cloud-obeoneorg-cloud \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:latest \
    --target base \
    --push \
    .

# Docker
docker buildx build \
    --builder cloud-obeoneorg-cloud \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:docker \
    --target docker \
    --push \
    .

# nerdctl
docker buildx build \
    --builder cloud-obeoneorg-cloud \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:nerdctl \
    --target nerdctl \
    --push \
    .

# nerdctl
docker buildx build \
    --builder cloud-obeoneorg-cloud \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:nerdctl \
    --target nerdctl \
    --push \
    .

# podman
docker buildx build \
    --builder cloud-obeoneorg-cloud \
    --platform linux/amd64,linux/arm64 \
    -t obeoneorg/netshoot:podman \
    --target podman \
    --push \
    .

