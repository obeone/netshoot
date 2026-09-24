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

# Optional: GitHub token secret (avoids API rate limits), version pins, weekly cache bust
GITHUB_TOKEN=$(gh auth token) docker build \
  --secret id=github_token,env=GITHUB_TOKEN \
  --build-arg GRPCURL_VERSION=v1.9.4 \
  --build-arg CACHE_BUST="$(date -u +%G-W%V)" \
  -t netshoot:local .
```

BuildKit is required (bind, cache and secret mounts; `# syntax=docker/dockerfile:1`).

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

**Note**: `build.sh` always pushes (`--push`). It requires a configured buildx builder (default: `cloud-obeoneorg-cloud`) and targets `linux/amd64,linux/arm64`. It always passes `--build-arg CACHE_BUST=<ISO week>` (`date -u +%G-W%V`, or `$CACHE_BUST` if already set in the environment), and passes `--secret id=github_token,env=GITHUB_TOKEN` when `GITHUB_TOKEN` is set.

### Testing images

```bash
# Automated smoke test (same script as CI): tests/smoke.sh <variant> <image>
bash tests/smoke.sh base netshoot:local
bash tests/smoke.sh docker netshoot:docker-local
bash tests/smoke.sh slim netshoot:slim-local

# Interactive
docker run -it --rm netshoot:local
docker run -it --rm --network=host netshoot:local
docker run -it --rm --network=container:<target> netshoot:local
docker run -it --rm --user 1000:1000 netshoot:local   # shell must work for any uid
docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock netshoot:docker-local
```

## Architecture

### Multi-Stage Dockerfile Structure

Both Dockerfiles start with a named `uv` stage (`FROM ghcr.io/astral-sh/uv:<ver>@sha256:<digest> AS uv`), only used as a `COPY --from=uv /uv /uvx /usr/local/bin/` source. It is a `FROM` line rather than `COPY --from=<image>` so Dependabot can bump it. All variant stages extend from `base`. The stage graph is flat (no chaining between variants):

```text
uv (ghcr.io/astral-sh/uv@sha256) ──COPY /uv /uvx──┐
                                                  ▼
                           debian:trixie@sha256 → base → docker
                                                       → podman
                                                       → nerdctl
                                                       → containerd
```

The base image is pinned as `debian:trixie@sha256:<digest>` (tag kept so Dependabot bumps the digest), in both Dockerfiles. `.github/workflows/dependabot-auto-merge.yml` never auto-merges docker-ecosystem PRs: the gatekeeper does not build Dependabot PRs, so a maintainer approves, re-runs the build (smoke test) and merges by hand.

- **`base`**: Installs all networking/system tools, the upstream-release binaries, Zsh with Oh My Zsh + Powerlevel10k, plugins, and helper scripts
- **`docker`**: Docker CLI only (`docker-ce-cli`, `docker-buildx-plugin`, `docker-compose-plugin`) from Docker's official apt repo. No `dockerd`, no `containerd.io`: users mount the host socket (`-v /var/run/docker.sock:/var/run/docker.sock`)
- **`podman`**: Adds Podman + fuse-overlayfs from Debian repos
- **`nerdctl`**: Downloads nerdctl client binary from GitHub releases (with SHA256 verification)
- **`containerd`**: Downloads nerdctl-full from GitHub releases (includes containerd); uses a custom entrypoint that starts containerd before exec

`Dockerfile.slim` is a separate file with the same `uv` stage, a single `base` stage and a reduced package set (includes `bind9-dnsutils` for dig/host/nslookup, `less`, `iputils-tracepath`, uv, check-tls and witr; no kubectl/doggo/websocat/grpcurl/man-db).

Both files end the base stage with `WORKDIR /root` and `CMD ["zsh"]` (exec form, so the shell's exit code is the container's). The containerd variant's `ENTRYPOINT` starts containerd, then execs the `CMD`.

### Tool Installation Patterns

The Dockerfile uses three distinct installation methods. When adding a tool, choose the appropriate one:

1. **Apt packages** (most tools): Add to `CORE_TOOLS`, `SYSTEM_TOOLS`, or `NETWORKING_TOOLS` arrays in the base stage (`NETWORKING_TOOLS_SLIM` / `SYSTEM_TOOLS_SLIM` in `Dockerfile.slim`). Arrays must stay alphabetically sorted. Prefer the real package over a transitional one (trixie: `dnsutils` → `bind9-dnsutils`; `dstat` pulls in pcp; `bind9-utils` has no dig/host/nslookup).
2. **Custom apt repository** (e.g., Ookla speedtest, Docker CLI): Add GPG key to `/etc/apt/keyrings/`, add sources list entry, then `apt-get install`. See the speedtest block in Dockerfile.
3. **Upstream release binary** (grpcurl, witr, doggo, websocat, kubectl, nerdctl): Create `scripts/install-<tool>.sh` that sources `scripts/lib.sh`, resolves the version (`resolve_version "${<TOOL>_VERSION:-}" <owner/repo>`), maps `TARGETARCH` to the project's naming convention, downloads with `fetch`, verifies with `verify_sha256` when upstream publishes checksums, installs to `/usr/local/bin` and ends with a version check. kubectl is the exception to the GitHub lookup: its latest version comes from `https://dl.k8s.io/release/stable.txt` and it is verified against the `.sha256` file next to the binary. The scripts are **not** copied into the image; the Dockerfile runs them from a bind mount:

   ```dockerfile
   ARG GRPCURL_VERSION=
   RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
       --mount=type=cache,target=/tmp/grpcurl,id=grpcurl-${TARGETARCH} \
       --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
       bash /tmp/scripts/install-grpcurl.sh
   ```

   Declare the `<TOOL>_VERSION` ARG (default empty = latest) right before the RUN that uses it, so a change only invalidates that step (ARGs are exported to the RUN environment, which is how the script receives it). The `github_token` secret is optional: it is absent on fork PRs and in plain local builds, and `lib.sh` then falls back to the `releases/latest` redirect.

Additionally, `uv` and `uvx` come from the pinned `uv` stage, and `check-tls` is installed with `uv tool install` using inline `UV_TOOL_DIR=/opt/uv/tools UV_TOOL_BIN_DIR=/usr/local/bin` (not a persistent `ENV`), so it is usable by any uid. That RUN keeps the `/root/.cache` cache mount for uv.

Version override build args (all default to empty = latest):

| ARG | Stage(s) |
|---|---|
| `GRPCURL_VERSION`, `DOGGO_VERSION`, `WEBSOCAT_VERSION`, `KUBECTL_VERSION` | `base` (Dockerfile) |
| `WITR_VERSION` | `base` (Dockerfile and Dockerfile.slim) |
| `NERDCTL_VERSION` | `nerdctl`, `containerd` |

### Key Design Patterns

- **BuildKit cache mounts**: Every `apt-get` step mounts two distinct caches, `/var/cache/apt` with `id=apt-cache-${TARGETARCH}` and `/var/lib/apt` with `id=apt-lists-${TARGETARCH}`, both `sharing=locked`, with the same ids in both Dockerfiles. Never `apt-get clean` or `rm -rf /var/lib/apt/lists/*` inside these mounts: it saves nothing in the image and wipes the shared cache. Every RUN that runs `apt-get install` starts with its own `apt-get update`: a layer cache hit does not bring the cache mount along (CI runners start with an empty one), so lists left by an earlier RUN may be missing or stale. Download steps use a per-tool, per-arch cache (`id=<tool>-${TARGETARCH}` on `/tmp/<tool>`).
- **Weekly refresh (`CACHE_BUST`)**: The base stage of both files declares `ARG CACHE_BUST=` right before the `apt-get full-upgrade` RUN, which echoes it. A new value reruns the upgrade and every later layer. CI and `build.sh` pass the ISO week (`date -u +%G-W%V`); CI computes it once per run in the gatekeeper so every job shares it and variants still hit the base cache.
- **Architecture detection**: `TARGETARCH` build arg is declared per-stage (`ARG TARGETARCH`) and mapped to project-specific arch names in `case` blocks (amd64, arm64; nerdctl also keeps arm)
- **Checksum verification**: grpcurl (`grpcurl_<ver>_checksums.txt`), witr and nerdctl (`SHA256SUMS`), doggo (`doggo_<ver>_checksums.txt`) and kubectl (`.sha256`) are verified. websocat publishes no checksum file upstream, so only its version is checked. Sums files in cache mounts are stored per version (e.g. `SHA256SUMS-<tag>`) and every download is atomic (`fetch`), so parallel stages and version bumps never clobber each other.
- **Pinning**: base image and uv by digest; Oh My Zsh, zsh-autosuggestions, zsh-completions, fast-syntax-highlighting and Powerlevel10k by commit (readonly variables at the top of `scripts/install-omz.sh`, with bump instructions). Apt packages are not pinned (hadolint DL3008 is ignored): the weekly rebuild keeps them current.
- **Layer optimization**: `COPY --link` for config files enables better layer sharing across variants
- **Shell**: `SHELL ["/bin/bash", "-o", "pipefail", "-c"]` in the base stage, and heredoc RUN bodies use `set -eux`.
- **gitstatus binary persistence**: The Powerlevel10k gitstatus install uses `GITSTATUS_CACHE_DIR=$ZSH/custom/themes/powerlevel10k/gitstatus/usrbin`, a path *outside* the `/root/.cache` cache mount. Without this, the compiled binary would live only in the cache mount and be absent from the final image layer.
- **Locale**: `LANG=C.UTF-8`, the only UTF-8 locale built into Debian without the `locales` package (`en_US.UTF-8` is not generated, and `man` complained about it on every call).
- **man pages**: `man-db` is installed in the full image. Before the install, any dpkg `path-exclude=/usr/share/man` rule in `/etc/dpkg/dpkg.cfg.d/` is removed so pages actually land (the pinned image has none today; it is a guard).

### Shell Layout (works for root and any uid)

- `ENV ZDOTDIR=/etc/zsh/netshoot`, containing `.zshrc` (from `configs/zshrc`), `.p10k.zsh` (from `configs/p10k.zsh`) and a `.zshenv` generated in the Dockerfile that sets `skip_global_compinit=1` (so a global zshrc never runs compinit before Oh My Zsh) and sources a user's `~/.zshenv` if present. `.zprofile`, `.zlogin` and `.zlogout` are generated there too and only forward to the user's `~/.zprofile`, `~/.zlogin`, `~/.zlogout` (zsh would not read them otherwise, since ZDOTDIR is set).
- Oh My Zsh, plugins and theme live in `/opt/oh-my-zsh` (world-readable). Nothing zsh-related is in `/root`; do not create `/root/.zshrc`, and there is no `/root/.oh-my-zsh` (a user's own `~/.zshrc` must use `ZSH=/opt/oh-my-zsh`, as the README says).
- `configs/zshrc` must work for `HOME=/root` and for `docker run --user 1000:1000` (no passwd entry, `HOME=/` not writable):
  - A user's own `~/.zshrc` (if it exists and is not the bundled file) is sourced instead of the bundled config, then it returns (replace semantics).
  - Cache dir: `$XDG_CACHE_HOME` or `$HOME/.cache` when writable, else `${TMPDIR:-/tmp}/netshoot-$UID` (then exported as `XDG_CACHE_HOME`). `ZSH_COMPDUMP` and `ZSH_CACHE_DIR` go under it. This runs before the p10k instant-prompt block.
  - `HISTFILE`: a pre-set value is respected, else `$HOME/.zsh_history` when writable, else under the cache dir.
  - `ZSH=/opt/oh-my-zsh`, OMZ auto-update disabled, `~/.zshrc.local` and `~/.zshrc.secrets` sourced before `oh-my-zsh.sh` (so `plugins+=()` works), `~/.p10k.zsh` used if present, else `$ZDOTDIR/.p10k.zsh`.
  - `sjs` uses `sudo` only when `EUID != 0` and sudo exists (sudo is not installed in the image).

### Configuration Files

- `configs/zshrc` — Zsh configuration with Oh My Zsh setup (installed as `/etc/zsh/netshoot/.zshrc`)
- `configs/p10k.zsh` — Powerlevel10k theme configuration (installed as `/etc/zsh/netshoot/.p10k.zsh`)
- `configs/podman-storage.conf` — Podman storage config for rootless operation
- `tools/transfer.sh` — File transfer helper script (installed to `/usr/local/bin/transfer.sh`)
- `entrypoint-containerd.sh` — Entrypoint for containerd variant (starts containerd daemon, then exec's the user command)

### Installation Scripts

Reusable installation scripts live in `scripts/` and run from a bind mount at `/tmp/scripts` (never copied into the image). Each script uses `#!/usr/bin/env bash` with `set -euo pipefail` plus `-x` (xtrace is turned off while a token is in scope), has a header comment listing its environment variables, expects `TARGETARCH` (set automatically by Docker BuildKit) and ends with a version check.

- `scripts/lib.sh` — sourced, not executed (`. "$(dirname "$0")/lib.sh"`). Helpers:
  - `gh_latest_tag <owner/repo>`: GitHub API `releases/latest` with the token when `GITHUB_TOKEN` is non-empty, otherwise the tag from the `https://github.com/<owner>/<repo>/releases/latest` redirect. Fails loudly if the result does not look like a tag. Never prints the token.
  - `resolve_version <override> <owner/repo>`: the override if non-empty, else `gh_latest_tag`.
  - `fetch <url> <dest>`: atomic download (temporary part file, then `mv`); skipped if `<dest>` already exists.
  - `verify_sha256 <file> <sums-file> <asset-name>`: exact, anchored match on the file name (`hash  name` or `hash *name`), fails if absent or ambiguous, then `sha256sum -c`.
- `scripts/install-omz.sh` — Oh My Zsh + plugins + Powerlevel10k + gitstatus into `/opt/oh-my-zsh`, each git-fetched at a pinned commit (no `curl | bash`); shared by both Dockerfiles
- `scripts/install-nerdctl.sh` — nerdctl (`NERDCTL_VERSION`) with SHA256 verification; accepts `client` or `full` argument
- `scripts/install-grpcurl.sh` — grpcurl (`GRPCURL_VERSION`) with SHA256 verification
- `scripts/install-witr.sh` — witr (`WITR_VERSION`) with SHA256 verification (shared by both Dockerfiles; not packaged for trixie)
- `scripts/install-doggo.sh` — doggo DNS client (`DOGGO_VERSION`) with SHA256 verification (not packaged for trixie)
- `scripts/install-websocat.sh` — websocat static musl binary (`WEBSOCAT_VERSION`); no upstream checksum, version check only (not packaged for trixie)
- `scripts/install-kubectl.sh` — kubectl (`KUBECTL_VERSION`, default from dl.k8s.io `stable.txt`) with `.sha256` verification (trixie's 1.32 is too old)

## Versioning

This project uses [release-please](https://github.com/googleapis/release-please) for automated semantic versioning based on conventional commits.

### How it works

1. Every push to `main` triggers the `release-please` workflow
2. release-please analyzes commits since the last release and creates/updates a "Release PR" with a computed version bump and changelog
3. When the Release PR is merged, release-please creates a git tag (`vX.Y.Z`) and a GitHub Release
4. The same workflow then dispatches build-and-publish on the new tag, which publishes the SemVer-tagged Docker images

That dispatch is explicit because the tag alone starts nothing: release-please pushes it with the default `GITHUB_TOKEN`, and GitHub does not start new workflow runs for events created by that token. `workflow_dispatch` is one of the two exceptions to that rule, so no PAT is involved. Floating tags are unaffected, they are published by the push to `main`.

To publish a tag by hand (an older tag, or a release whose dispatch failed):

```bash
gh workflow run build-and-publish.yaml --ref vX.Y.Z
```

### Version bump policy

| Commit type | Effect | Example |
|---|---|---|
| `feat` | **minor** bump | New tool, new image variant |
| `fix`, `perf` | **patch** bump | Bug fix, performance improvement |
| `docs`, `ci`, `chore`, `style`, `refactor`, `build`, `test` | **patch** bump, in its own changelog section | Documentation, CI, maintenance |
| `BREAKING CHANGE` footer or `!` after type (e.g., `feat!:`) | **major** bump | Base image change, tool removal, entrypoint change |

Every conventional type is declared as a visible section in `release-please-config.json`, and release-please counts a visible section as a releasable unit. So any conventional commit is enough to cut a patch release, including a CI or docs one. To make a type neither bump the version nor show up in the changelog, mark its section `"hidden": true`.

### Configuration files

- `release-please-config.json` — release-please settings (release type, changelog sections)
- `.release-please-manifest.json` — tracks current version (updated automatically by release-please)

### Creating a release

Do not create tags manually. Merge the release-please PR on GitHub to trigger a release. The PR title and body show the computed version and changelog before merging. The images are then built and pushed without further action.

## CI/CD

GitHub Actions workflows:

- `.github/workflows/build-and-publish.yaml` — builds, smoke tests and publishes Docker images
- `.github/workflows/release-please.yaml` — manages releases and version tags
- `.github/workflows/lint.yaml` — shellcheck, hadolint and actionlint (see "Testing and Linting")
- `.github/actions/compute-tags` — composite action computing image tags per variant and event

### Published registries

- **GHCR**: `ghcr.io/obeone/netshoot`
- **Docker Hub**: `docker.io/obeoneorg/netshoot`

### Trigger behavior

- **Push to `main`**: Publishes floating tags (latest, docker, podman, etc.) to both registries. Signs images with cosign (OIDC keyless).
- **Weekly schedule** (`cron: '17 4 * * 1'`, Monday 04:17 UTC): behaves like a push to `main` (floating tags, signing), so images pick up Debian security updates without a merge. The gatekeeper treats `schedule` like `push` (and skips it outside `obeone/netshoot`); compute-tags accepts it (ref is `refs/heads/main`).
- **Push tag `v*.*.*`** (or `workflow_dispatch` on a tag): Publishes SemVer tags per variant (e.g., `1.2.3`, `1.2.3-docker`, `1.2-docker`, `1-docker`) to both registries. Signs images.
- **Pull requests** (`pull_request`): Build-only (no push) to validate Docker builds succeed, smoke test included. Only runs if PR author is trusted or PR is approved by an org OWNER/MEMBER. Uses `concurrency` to cancel in-progress PR builds when new commits are pushed.

### Build job structure

- The gatekeeper also outputs `cache_bust` (ISO week). Every build step (base, slim, variants; smoke and push builds) passes `build-args: CACHE_BUST=<that output>` and `secrets: github_token=${{ secrets.GITHUB_TOKEN }}`.
- **Smoke test gate**: in each matrix job, before the multi-arch build, a `docker/build-push-action` step builds `linux/amd64` only with `load: true`, `push: false`, tag `netshoot-smoke:<variant>` (same file/target/cache-from/build-args/secrets, no cache-to), then `bash tests/smoke.sh <variant> netshoot-smoke:<variant>` runs. The multi-arch build that follows reuses those amd64 layers.
- **OCI metadata**: `docker/metadata-action@v5` produces labels and annotations (`DOCKER_METADATA_ANNOTATIONS_LEVELS=manifest,index`): version (SemVer without `v` on tag builds, branch name otherwise), revision, created, licenses (MIT), source, plus per-variant `title` / `description` from matrix fields that must match the Dockerfile stage `LABEL`s. compute-tags stays the source of the image tags.
- **Supply chain**: the push build sets `provenance: mode=max` and `sbom: true` only when pushing (false otherwise). Cosign signs the pushed digest.

### Required secrets

- `DOCKERHUB_USERNAME` (repository variable), `DOCKERHUB_TOKEN` (secret); the Docker Hub push is skipped when they are missing
- `GITHUB_TOKEN` (built-in) for GHCR, and passed to builds as the `github_token` BuildKit secret for GitHub API lookups

### CI vs local build caching

The CI workflow uses `type=gha` (GitHub Actions cache, `scope=buildkit-<variant>`; variants also read `scope=buildkit-base`). The `build.sh` script uses `type=registry` (registry-based cache at `obeoneorg/netshoot-cache`). These are independent cache stores. Both invalidate the apt upgrade layer weekly through `CACHE_BUST`.

## Image Variants and Tags

**Debian (full) variants:**

- `latest`, `debian`, `debian-latest` → base stage
- `docker`, `debian-docker` → docker stage (CLI only)
- `podman`, `debian-podman` → podman stage
- `nerdctl`, `debian-nerdctl` → nerdctl stage
- `containerd`, `debian-containerd` → containerd stage

**Slim variants:**

- `slim`, `slim-latest` → base stage (reduced toolset)

## Testing and Linting

There is no `make`, `npm`, or test runner; the checks are plain scripts and CI workflows.

- **Smoke test**: `tests/smoke.sh <variant> <image>` (variants: `base`, `slim`, `docker`, `podman`, `nerdctl`, `containerd`) runs every check in `docker run --rm --entrypoint /bin/bash <image> -c '...'` (entrypoint overridden so the containerd variant needs no privileges) and reports PASS/FAIL per check, exiting 1 on any failure. It checks: expected binaries present and removed ones (dstat, sudo) absent (pip/pip3 are not checked: `httpie` and `python3-venv` depend on `python3-pip` in trixie, so pip stays installed), per variant; functional checks (grpcurl, witr, doggo, websocat, kubectl, `check-tls --help` as uid 1000, `python3 -m venv`, `man -w tcpdump` on the full image); an interactive zsh as root and as `--user 1000:1000`, both without a terminal and on a `docker run -t` pty (`timeout --foreground -k`), which must print a probe marker proving the bundled config loaded (`ZSH=/opt/oh-my-zsh`, `p10k` defined, `ZSH_COMPDUMP` set), with no error output and no newuser/p10k wizard; variant tools (docker CLI + buildx + compose with `dockerd` absent, podman, nerdctl, containerd + nerdctl). Run it on a locally built image; CI runs it for every variant before pushing.
- **Lint** (`.github/workflows/lint.yaml`, on `pull_request` and push to `main`, `contents: read`): shellcheck on `build.sh`, `entrypoint-containerd.sh`, `tools/transfer.sh`, `scripts/*.sh` and `tests/*.sh` (`scripts/lib.sh` is sourced, the install scripts point shellcheck at it with a `source` directive); hadolint on `Dockerfile` and `Dockerfile.slim` with `.hadolint.yaml` (it ignores no rule globally: rules are ignored inline with `# hadolint ignore=<rule>` above the instruction, with a justification comment); actionlint on the workflows. Linter binaries are pinned by version and SHA256 in the workflow.
- README.md must stay markdownlint-clean per `.markdownlint.json` (80-column lines outside code blocks and tables).

All shell scripts (`build.sh`, `entrypoint-containerd.sh`, `tools/transfer.sh`, `scripts/*.sh`, `tests/*.sh`) use `bash` and must pass shellcheck.

## Development Notes

### Adding New Tools

1. Choose the correct installation method (see "Tool Installation Patterns" above)
2. For apt packages: add to the appropriate sorted array (`CORE_TOOLS`, `SYSTEM_TOOLS`, or `NETWORKING_TOOLS`)
3. For upstream binaries: add `scripts/install-<tool>.sh` using `lib.sh`, a `<TOOL>_VERSION` ARG right before its bind-mount RUN, and a per-arch cache id
4. Consider if the tool should also be in the slim variant (`Dockerfile.slim`)
5. Add the binary to the expected lists in `tests/smoke.sh` (`FULL_PRESENT`, `SLIM_PRESENT`), plus a functional check if it has a `--version`
6. Document the tool in the README.md tools section and complete package list

### Adding a New Variant

1. Create new stage in Dockerfile: `FROM base AS newvariant`
2. Add target to `TARGETS["debian"]` in `build.sh`: `newvariant:debian-newvariant,newvariant`
3. Add matrix entry in `.github/workflows/build-and-publish.yaml` with variant, dockerfile, target, floating_tags, semver_suffix, title and description (title/description must match the stage's `LABEL`s)
4. Add the variant to `tests/smoke.sh` (usage, `case` of accepted variants, variant-specific checks)
5. Update README.md with new variant description

### Cache Management

- **Local BuildKit cache**: Per-architecture apt caches (`apt-cache-<arch>`, `apt-lists-<arch>`) and per-tool download caches (`<tool>-<arch>`). Clear with `docker builder prune` or use `--no-cache` flag. To rerun only the upgrade and later layers, pass a new `CACHE_BUST` value.
- **Registry cache** (`build.sh` only): Per-build-tag cache refs at `obeoneorg/netshoot-cache:<tag>`. Disabled with `--no-cache`.
- **GHA cache** (CI only): Managed automatically by GitHub Actions.
