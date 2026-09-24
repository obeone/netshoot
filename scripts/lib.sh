# shellcheck shell=bash
#
# Shared helpers for the install-*.sh scripts.
#
# This file is sourced, not executed:
#
#   . "$(dirname "$0")/lib.sh"
#
# Optional environment variables:
#   GITHUB_TOKEN  - GitHub token used to query the releases API. When empty or
#                   unset, the latest tag is read from the redirect of
#                   https://github.com/<owner>/<repo>/releases/latest instead,
#                   which needs no token and is not subject to the API rate
#                   limit. The token is never printed: xtrace is turned off
#                   whenever it is in scope.
#
# All functions report errors on stderr and return non-zero; callers run with
# `set -e`, so a failed helper aborts the build.

# die <message...>
#
# Print an error on stderr and exit.
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# looks_like_tag <string>
#
# Succeed when the argument is plausible as a release tag: a single path
# segment made of safe characters that contains at least one digit. This
# rejects the "releases" or "latest" segments GitHub returns when a repository
# has no release, as well as empty strings and anything with a slash.
looks_like_tag() {
    [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] &&
        [[ "$1" =~ [0-9] ]] &&
        [[ "$1" != "latest" ]]
}

# gh_latest_tag <owner/repo>
#
# Print the tag of the latest GitHub release of <owner/repo> on stdout.
gh_latest_tag() {
    # Disable xtrace before anything expands GITHUB_TOKEN, and restore it on
    # the way out. The braces and redirect keep "set +x" itself out of the log.
    local xtrace=0
    case "$-" in *x*) xtrace=1 ;; esac
    { set +x; } 2>/dev/null

    local repo="${1:?Usage: gh_latest_tag <owner/repo>}"
    local tag="" url=""

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        # The header is fed on stdin (-H @-) so the token never shows up in
        # the process list. printf is a builtin, so it does not either.
        tag=$(printf 'Authorization: Bearer %s\n' "$GITHUB_TOKEN" |
            curl -fsSL --retry 3 --retry-connrefused \
                -H @- \
                -H 'Accept: application/vnd.github+json' \
                -H 'X-GitHub-Api-Version: 2022-11-28' \
                "https://api.github.com/repos/${repo}/releases/latest" |
            jq -r '.tag_name // empty') || tag=""
        if [[ -z "$tag" ]]; then
            echo "WARNING: GitHub API lookup failed for ${repo}, falling back to the releases/latest redirect" >&2
        fi
    fi

    if [[ -z "$tag" ]]; then
        # /releases/latest answers with a redirect to /releases/tag/<tag>.
        url=$(curl -fsSLI --retry 3 --retry-connrefused -o /dev/null \
            -w '%{url_effective}' \
            "https://github.com/${repo}/releases/latest") || url=""
        tag="${url##*/}"
    fi

    if [[ "$xtrace" -eq 1 ]]; then set -x; fi

    if ! looks_like_tag "$tag"; then
        echo "ERROR: could not determine the latest release tag of ${repo} (got '${tag}')" >&2
        return 1
    fi
    printf '%s\n' "$tag"
}

# resolve_version <override> <owner/repo>
#
# Print <override> when it is non-empty, otherwise the latest release tag of
# <owner/repo>. The override comes from a *_VERSION build arg.
resolve_version() {
    local override="${1:-}"
    local repo="${2:?Usage: resolve_version <override> <owner/repo>}"

    if [[ -n "$override" ]]; then
        if ! looks_like_tag "$override"; then
            echo "ERROR: invalid version override for ${repo}: '${override}'" >&2
            return 1
        fi
        printf '%s\n' "$override"
        return 0
    fi
    gh_latest_tag "$repo"
}

# fetch <url> <dest>
#
# Download <url> to <dest> atomically: the body goes to a unique temporary file
# next to <dest>, which is renamed into place only once the download is
# complete. A <dest> that already exists (a cache hit) is left untouched, so
# callers must verify it afterwards. Concurrent builds sharing the same cache
# mount therefore never see a truncated file.
fetch() {
    local url="${1:?Usage: fetch <url> <dest>}"
    local dest="${2:?Usage: fetch <url> <dest>}"
    local part

    if [[ -s "$dest" ]]; then
        echo "Using cached ${dest}" >&2
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    # $$ alone is not unique across build containers (each has its own PID
    # namespace), so mktemp adds a random suffix.
    part=$(mktemp "${dest}.part.$$.XXXXXX")

    echo "Downloading ${url}" >&2
    if ! curl -fsSL --retry 3 --retry-connrefused -o "$part" "$url"; then
        rm -f "$part"
        echo "ERROR: download failed: ${url}" >&2
        return 1
    fi
    chmod 0644 "$part"
    mv -f "$part" "$dest"
}

# verify_sha256_hash <file> <expected-hash>
#
# Check <file> against a bare SHA256 hex digest. On mismatch the file is
# removed, so that a corrupted cache entry is downloaded again next time.
verify_sha256_hash() {
    local file="${1:?Usage: verify_sha256_hash <file> <hash>}"
    local hash="${2:?Usage: verify_sha256_hash <file> <hash>}"

    if [[ ! "$hash" =~ ^[0-9a-fA-F]{64}$ ]]; then
        echo "ERROR: malformed SHA256 for ${file}: '${hash}'" >&2
        return 1
    fi
    if ! printf '%s  %s\n' "$hash" "$file" | sha256sum -c -; then
        echo "ERROR: SHA256 mismatch for ${file}, removing it" >&2
        rm -f "$file"
        return 1
    fi
}

# verify_sha256 <file> <sums-file> <asset-name>
#
# Check <file> against the entry for <asset-name> in <sums-file>, a
# sha256sum-style list ("<hash>  <name>" or "<hash> *<name>"). The name must
# match exactly: no substring or regex match, so "witr-linux-amd64" cannot
# pick up "witr-linux-amd64.deb". Exactly one entry must match.
verify_sha256() {
    local file="${1:?Usage: verify_sha256 <file> <sums-file> <asset-name>}"
    local sums="${2:?Usage: verify_sha256 <file> <sums-file> <asset-name>}"
    local asset="${3:?Usage: verify_sha256 <file> <sums-file> <asset-name>}"
    local hashes count

    hashes=$(awk -v asset="$asset" '
        { sub(/\r$/, "") }
        NF == 2 {
            name = $2
            sub(/^\*/, "", name)
            if (name == asset) print $1
        }' "$sums")
    count=$(printf '%s' "$hashes" | grep -c . || true)

    if [[ "$count" -eq 0 ]]; then
        echo "ERROR: no checksum for ${asset} in ${sums}" >&2
        return 1
    fi
    if [[ "$count" -gt 1 ]]; then
        echo "ERROR: ${count} checksums for ${asset} in ${sums}, expected one" >&2
        return 1
    fi
    verify_sha256_hash "$file" "$hashes"
}
