# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Netshoot is a Docker-based network troubleshooting toolkit built on Debian 13 Trixie (stable). It provides multiple variants (base, docker, podman, nerdctl, containerd) through a multi-stage Dockerfile architecture, each tailored for specific container runtime needs. A slim variant with a reduced toolset is also available.

## Build Commands

### Local development build (single platform, no push)

```bash
# Build base variant locally
docker build -t netshoot:local .

# Build a specific variant
docker build --target docker -t netshoot:docker-local .
docker build --target podman -t netshoot:podman-local .

# Build slim variant
docker build -f Dockerfile.slim -t netshoot:slim-local .
```

### Production build (multi-platform, pushes to registry)

```bash
# Build all types and targets
./build.sh

# Build specific type (debian or slim)
./build.sh --type=debian
./build.sh --type=slim

# Build specific target for a type
./build.sh --type=debian --target=base
./build.sh --type=debian --target=docker

# Disable registry cache
./build.sh --no-cache

# Specify custom builder
./build.sh --builder=my-builder
```

**Note**: `build.sh` always pushes (`--push`). It requires a configured buildx builder (default: `cloud-obeoneorg-cloud`) and targets `linux/amd64,linux/arm64`.

### Testing images

```bash
docker run -it --rm netshoot:local
docker run -it --rm --network=host netshoot:local
docker run -it --rm --network=container:<target> netshoot:local
```

## Architecture

### Multi-Stage Dockerfile Structure

All variant stages extend from `base`. The stage graph is flat (no chaining between variants):

```
debian:trixie → base → docker
                     → podman
                     → nerdctl
                     → containerd
```

- **`base`**: Installs all networking/system tools, Zsh with Oh My Zsh + Powerlevel10k, plugins, and helper scripts
- **`docker`**: Adds Docker CE + buildx + compose from Docker's official apt repo
- **`podman`**: Adds Podman + fuse-overlayfs from Debian repos
- **`nerdctl`**: Downloads nerdctl client binary from GitHub releases (with SHA256 verification)
- **`containerd`**: Downloads nerdctl-full from GitHub releases (includes containerd); uses a custom entrypoint that starts containerd before exec

`Dockerfile.slim` is a separate file with a single `base` stage and a reduced package set.

### Tool Installation Patterns

The Dockerfile uses three distinct installation methods. When adding a tool, choose the appropriate one:

1. **Apt packages** (most tools): Add to `CORE_TOOLS`, `SYSTEM_TOOLS`, or `NETWORKING_TOOLS` arrays in the base stage. Arrays must stay alphabetically sorted.
2. **Custom apt repository** (e.g., Ookla speedtest): Add GPG key to `/etc/apt/keyrings/`, add sources list entry, then `apt-get install`. See the speedtest block in Dockerfile.
3. **GitHub releases binary** (e.g., grpcurl, nerdctl): Create a script in `scripts/` that queries GitHub API for the latest tag, maps `TARGETARCH` to the project's naming convention, downloads and extracts the binary. The Dockerfile COPYs the script and runs it with a `--mount=type=cache` on a dedicated `/tmp/<tool>` directory. See `scripts/install-grpcurl.sh` and `scripts/install-nerdctl.sh` for examples.

Additionally, `uv` is copied directly from `ghcr.io/astral-sh/uv:latest`, and `check-tls` is installed via `uv tool install`.

### Key Design Patterns

- **BuildKit cache mounts**: All `apt-get` and download steps use `--mount=type=cache` with architecture-specific IDs (`id=apt-${TARGETARCH}`) and `sharing=locked` for parallel build safety.
- **Architecture detection**: `TARGETARCH` build arg is declared per-stage (`ARG TARGETARCH`) and mapped to project-specific arch names in `case` blocks
- **Checksum verification**: nerdctl downloads verify SHA256SUMS; grpcurl does not (only version verification)
- **Layer optimization**: `COPY --link` for config files enables better layer sharing across variants
- **gitstatus binary persistence**: The Powerlevel10k gitstatus install uses `GITSTATUS_CACHE_DIR` pointed to a path *outside* the `/root/.cache` cache mount. Without this, the compiled binary would live only in the cache mount and be absent from the final image layer.

### Configuration Files

- `configs/zshrc` — Zsh configuration with Oh My Zsh setup
- `configs/p10k.zsh` — Powerlevel10k theme configuration
- `configs/podman-storage.conf` — Podman storage config for rootless operation
- `tools/transfer.sh` — File transfer helper script (installed to `/usr/local/bin/transfer.sh`)
- `entrypoint-containerd.sh` — Entrypoint for containerd variant (starts containerd daemon, then exec's the user command)

### Installation Scripts

Reusable installation scripts live in `scripts/`. Each script uses `#!/usr/bin/env bash` with `set -eux` and expects `TARGETARCH` as an environment variable (set automatically by Docker BuildKit).

- `scripts/install-omz.sh` — Oh My Zsh + plugins + Powerlevel10k + gitstatus (shared by both Dockerfiles)
- `scripts/install-nerdctl.sh` — nerdctl download with SHA256 verification; accepts `client` or `full` argument
- `scripts/install-grpcurl.sh` — grpcurl from GitHub releases

## Versioning

This project uses [release-please](https://github.com/googleapis/release-please) for automated semantic versioning based on conventional commits.

### How it works

1. Every push to `main` triggers the `release-please` workflow
2. release-please analyzes commits since the last release and creates/updates a "Release PR" with a computed version bump and changelog
3. When the Release PR is merged, release-please creates a git tag (`vX.Y.Z`) and a GitHub Release
4. The existing build-and-publish workflow triggers on the new tag and publishes SemVer-tagged Docker images

### Version bump policy

| Commit type | Effect | Example |
|---|---|---|
| `feat` | **minor** bump | New tool, new image variant |
| `fix`, `perf` | **patch** bump | Bug fix, performance improvement |
| `docs`, `ci`, `chore`, `style`, `refactor`, `build`, `test` | changelog only (no bump) | Documentation, CI, maintenance |
| `BREAKING CHANGE` footer or `!` after type (e.g., `feat!:`) | **major** bump | Base image change, tool removal, entrypoint change |

### Configuration files

- `release-please-config.json` — release-please settings (release type, changelog sections)
- `.release-please-manifest.json` — tracks current version (updated automatically by release-please)

### Creating a release

Do not create tags manually. Merge the release-please PR on GitHub to trigger a release. The PR title and body show the computed version and changelog before merging.

## CI/CD

GitHub Actions workflows:

- `.github/workflows/build-and-publish.yaml` — builds and publishes Docker images
- `.github/workflows/release-please.yaml` — manages releases and version tags

### Published registries

- **GHCR**: `ghcr.io/obeone/netshoot`
- **Docker Hub**: `docker.io/obeoneorg/netshoot`

### Trigger behavior

- **Push to `main`**: Publishes floating tags (latest, docker, podman, etc.) to both registries. Signs images with cosign (OIDC keyless).
- **Push tag `v*.*.*`**: Publishes SemVer tags per variant (e.g., `1.2.3`, `1.2.3-docker`, `1.2-docker`, `1-docker`) to both registries. Signs images.
- **Pull requests** (`pull_request`): Build-only (no push) to validate Docker builds succeed. Only runs if PR author is trusted or PR is approved by an org OWNER/MEMBER. Uses `concurrency` to cancel in-progress PR builds when new commits are pushed.

### Required secrets

- `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- `GITHUB_TOKEN` (built-in) for GHCR

### CI vs local build caching

The CI workflow uses `type=gha` (GitHub Actions cache). The `build.sh` script uses `type=registry` (registry-based cache at `obeoneorg/netshoot-cache`). These are independent cache stores.

## Image Variants and Tags

**Debian (full) variants:**

- `latest`, `debian`, `debian-latest` → base stage
- `docker`, `debian-docker` → docker stage
- `podman`, `debian-podman` → podman stage
- `nerdctl`, `debian-nerdctl` → nerdctl stage
- `containerd`, `debian-containerd` → containerd stage

**Slim variants:**

- `slim`, `slim-latest` → base stage (reduced toolset)

## Testing and Linting

This project has no automated tests or linters. Validation is done by building the Docker image and running it interactively. There is no `make`, `npm`, or test runner to invoke.

All shell scripts (`build.sh`, `entrypoint-containerd.sh`, `tools/transfer.sh`, `scripts/*.sh`) use `bash`.

## Development Notes

### Adding New Tools

1. Choose the correct installation method (see "Tool Installation Patterns" above)
2. For apt packages: add to the appropriate sorted array (`CORE_TOOLS`, `SYSTEM_TOOLS`, or `NETWORKING_TOOLS`)
3. Consider if the tool should also be in the slim variant (`Dockerfile.slim`)
4. Document the tool in the README.md tools section

### Adding a New Variant

1. Create new stage in Dockerfile: `FROM base AS newvariant`
2. Add target to `TARGETS["debian"]` in `build.sh`: `newvariant:debian-newvariant,newvariant`
3. Add matrix entry in `.github/workflows/build-and-publish.yaml` with variant, dockerfile, target, floating_tags, and semver_suffix
4. Update README.md with new variant description

### Cache Management

- **Local BuildKit cache**: Per-architecture apt and download caches. Clear with `docker builder prune` or use `--no-cache` flag.
- **Registry cache** (`build.sh` only): Per-build-tag cache refs at `obeoneorg/netshoot-cache:<tag>`. Disabled with `--no-cache`.
- **GHA cache** (CI only): Managed automatically by GitHub Actions.
