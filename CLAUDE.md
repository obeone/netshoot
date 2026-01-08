# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Netshoot is a Docker-based network troubleshooting toolkit built on Debian 13 Trixie (stable). It provides multiple variants (base, docker, podman, nerdctl, containerd) through a multi-stage Dockerfile architecture, each tailored for specific container runtime needs.

## Build System

### Building Images

Use the [build.sh](build.sh) script to build and push images:

```bash
# Build all types and targets
./build.sh

# Build specific type (debian or slim)
./build.sh --type=debian
./build.sh --type=slim

# Build specific target for a type
./build.sh --type=debian --target=base
./build.sh --type=debian --target=docker
./build.sh --type=debian --target=podman

# Disable registry cache
./build.sh --no-cache

# Specify custom builder
./build.sh --builder=my-builder
```

**Available targets for debian type (Dockerfile):**
- `base` - Base image with networking tools (no container runtime)
- `docker` - Base + Docker CLI and docker-compose
- `podman` - Base + Podman runtime
- `nerdctl` - Base + nerdctl client only
- `containerd` - Base + nerdctl full version with containerd

**Available targets for slim type (Dockerfile.slim):**
- `base` - Slimmed-down version with essential tools only

### Build Configuration

The build script uses:
- **Multi-platform builds**: `linux/amd64,linux/arm64` by default
- **BuildKit cache mounts**: For faster apt operations and git clones
- **Registry cache**: Enabled by default for layer caching (`obeoneorg/netshoot-cache`)
- **Docker buildx**: Requires a configured builder (default: `cloud-obeoneorg-cloud`)

## Architecture

### Multi-Stage Dockerfile Structure

The [Dockerfile](Dockerfile) uses multi-stage builds:

1. **`base` stage**: Foundation stage that installs all networking and system tools, sets up Zsh with Oh My Zsh, Powerlevel10k theme, and plugins
2. **`docker` stage**: Extends base with Docker CLI from official Docker repository
3. **`podman` stage**: Extends base with Podman and fuse-overlayfs
4. **`nerdctl` stage**: Extends base with nerdctl client (downloads from GitHub releases)
5. **`containerd` stage**: Extends base with full nerdctl package including containerd (uses custom entrypoint)

The [Dockerfile.slim](Dockerfile.slim) provides a single `base` stage with a reduced tool set for smaller image size.

### Key Design Patterns

- **BuildKit cache optimization**: All stages use `--mount=type=cache` for apt and download caches to speed up rebuilds
- **Architecture detection**: Uses `TARGETARCH` build arg to download correct binaries for each platform
- **Checksum verification**: External downloads (nerdctl) verify SHA256 checksums
- **Layer reuse**: Uses `COPY --link` for better layer sharing across variants

### Configuration Files

- [configs/zshrc](configs/zshrc) - Zsh configuration with Oh My Zsh setup
- [configs/p10k.zsh](configs/p10k.zsh) - Powerlevel10k theme configuration
- [configs/podman-storage.conf](configs/podman-storage.conf) - Podman storage configuration for rootless operation
- [tools/transfer.sh](tools/transfer.sh) - Script for quick file transfers
- [entrypoint-containerd.sh](entrypoint-containerd.sh) - Entrypoint for containerd variant to start containerd daemon

## Testing Images

Run a container interactively:

```bash
# Test base image
docker run -it --rm obeoneorg/netshoot:latest

# Test docker variant
docker run -it --rm obeoneorg/netshoot:docker

# Test with host network
docker run -it --rm --network=host obeoneorg/netshoot
```

## Image Variants and Tags

The build system creates the following tags:

**Debian (full) variants:**
- `latest`, `debian`, `debian-latest` → base stage
- `docker`, `debian-docker` → docker stage
- `podman`, `debian-podman` → podman stage
- `nerdctl`, `debian-nerdctl` → nerdctl stage
- `containerd`, `debian-containerd` → containerd stage

**Slim variants:**
- `slim`, `slim-latest` → base stage (reduced toolset)

## Development Notes

### Adding New Tools

When adding tools to the Dockerfile:
1. Add package name to appropriate array (`NETWORKING_TOOLS` or `SYSTEM_TOOLS`) in the base stage
2. Keep arrays alphabetically sorted for maintainability
3. Consider if tool should also be in slim variant (update Dockerfile.slim accordingly)
4. Document the tool in the README.md tools table

### Modifying Build Targets

To add a new variant:
1. Create new stage in Dockerfile that extends `FROM base AS newvariant`
2. Add target to `TARGETS["debian"]` in build.sh: `newvariant:debian-newvariant,newvariant`
3. Update README.md with new variant description

### Cache Management

The build uses two types of caching:
- **Local BuildKit cache**: For apt packages and git repositories (per-architecture)
- **Registry cache**: For sharing layers between builds (`--cache-from/--cache-to`)

To clear local cache, remove the buildx builder cache or use `--no-cache`.
