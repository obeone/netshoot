#!/usr/bin/env bash
#
# Smoke test for a built netshoot image.
#
# Usage: tests/smoke.sh <variant> <image>
#   variant - one of: base, slim, docker, podman, nerdctl, containerd
#   image   - image reference already present in the local Docker engine
#             (e.g. netshoot-smoke:base, built with --load)
#
# Every check runs in a throwaway container started with
# `docker run --rm --entrypoint /bin/bash <image> -c '...'`. The entrypoint is
# overridden so the containerd variant does not try to start its daemon, which
# would need privileges. Each check prints PASS or FAIL; the script exits 1 if
# any check failed.
#
# Environment:
#   SMOKE_TIMEOUT - seconds allowed for each interactive zsh start (default 60)

set -euo pipefail

usage() {
    echo "Usage: $0 <base|slim|docker|podman|nerdctl|containerd> <image>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage
VARIANT=$1
IMAGE=$2
SMOKE_TIMEOUT=${SMOKE_TIMEOUT:-60}

case "$VARIANT" in
    base | slim | docker | podman | nerdctl | containerd) ;;
    *) usage ;;
esac

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Image not found in the local engine: $IMAGE" >&2
    exit 2
fi

# ------------------------------------------------------------------------------
# Expected tools
# ------------------------------------------------------------------------------

# Full image (base stage of Dockerfile, inherited by every Debian variant).
# Binary names, not package names (e.g. bind9-dnsutils -> dig/host/nslookup).
FULL_PRESENT=(
    # Packet capture and analysis
    tcpdump tshark termshark ngrep tcpflow dhcpdump
    # Scanning and probing
    nmap masscan arping arp-scan fping hping3 sslscan
    # DNS
    dig host nslookup doggo
    # Path and latency
    mtr traceroute tcptraceroute tracepath ping
    # Throughput
    iperf3 iperf netperf speedtest
    # Clients
    socat nc curl wget http ab telnet ssh swaks whois websocat grpcurl
    ldapsearch snmpwalk kubectl check-tls witr
    # Addressing and kernel networking
    ss ip nft iptables ipset ipvsadm conntrack wg ethtool brctl netstat sipcalc
    # Bandwidth monitors
    iftop nload bmon nethogs
    # System
    btop htop iotop iostat lsof strace ncdu rsync file
    # Shell, editors and utilities
    zsh bash tmux vim less man git jq fzf thefuck wormhole
    gpg openssl unzip zip python3 uv uvx transfer.sh
)
# Removed from the full image on purpose. pip/pip3 are not listed: python3-pip
# is no longer installed explicitly, but httpie and python3-venv (through
# python3.13-venv) both depend on it on trixie, so it is still pulled in.
FULL_ABSENT=(dstat sudo)

# Slim image (Dockerfile.slim).
SLIM_PRESENT=(
    tcpdump nmap fping
    dig host nslookup
    mtr traceroute tracepath ping
    iperf3
    socat nc curl wget http ab telnet ssh whois check-tls witr
    ss ip ethtool netstat
    btop lsof strace rsync file
    zsh bash tmux vim less git jq unzip zip python3 uv uvx transfer.sh
)
SLIM_ABSENT=(dstat sudo)

# ------------------------------------------------------------------------------
# Reporting helpers
# ------------------------------------------------------------------------------

passed=0
failed=0

pass() {
    printf 'PASS  %s\n' "$1"
    passed=$((passed + 1))
}

fail() {
    printf 'FAIL  %s\n' "$1"
    if [[ -n "${2:-}" ]]; then
        printf '%s\n' "$2" | sed 's/^/        /'
    fi
    failed=$((failed + 1))
}

# in_image [docker run options...] -- <bash script> [args...]
# Runs a bash script inside a fresh container of $IMAGE.
in_image() {
    local opts=()
    while [[ $# -gt 0 && "$1" != "--" ]]; do
        opts+=("$1")
        shift
    done
    [[ "${1:-}" == "--" ]] && shift
    local script=$1
    shift
    docker run --rm --pull never "${opts[@]}" --entrypoint /bin/bash "$IMAGE" -c "$script" smoke "$@"
}

# check <name> [docker run options...] -- <bash script>
# PASS if the script exits 0, FAIL (with its output) otherwise.
check() {
    local name=$1 out
    shift
    if out=$(in_image "$@" 2>&1); then
        pass "$name"
    else
        fail "$name" "$out"
    fi
}

# check_binaries <present|absent> <binary>...
# Probes every binary with `command -v` in a single container.
check_binaries() {
    local want=$1 out name state
    shift
    [[ $# -gt 0 ]] || return 0
    # shellcheck disable=SC2016 # expanded inside the container
    if ! out=$(in_image -- 'for b in "$@"; do
                if command -v "$b" >/dev/null 2>&1; then echo "$b yes"; else echo "$b no"; fi
            done' "$@" 2>&1); then
        fail "binary probe ($want)" "$out"
        return 0
    fi
    while read -r name state; do
        [[ -n "$name" ]] || continue
        if [[ "$want" == present && "$state" == yes ]]; then
            pass "present: $name"
        elif [[ "$want" == absent && "$state" == no ]]; then
            pass "absent: $name"
        elif [[ "$want" == present ]]; then
            fail "present: $name" "command -v $name found nothing"
        else
            fail "absent: $name" "$name should not be installed in the $VARIANT image"
        fi
    done <<<"$out"
}

# Run by every zsh check: succeeds only if the bundled configuration was really
# loaded (Oh My Zsh from /opt/oh-my-zsh, Powerlevel10k, a compdump path), so a
# bare zsh that read no config at all does not pass.
# shellcheck disable=SC2016 # expanded by zsh inside the container
ZSH_PROBE='[[ $ZSH == /opt/oh-my-zsh ]] && (( $+functions[p10k] )) && [[ -n $ZSH_COMPDUMP ]] && print -r -- NETSHOOT_ZSH_OK'

# check_zsh <name> <notty|tty> [docker run options...]
# Starts an interactive zsh that runs $ZSH_PROBE and exits. FAIL if it times
# out (a wizard waiting for input), exits non-zero, does not print the probe
# marker, prints error lines, or shows the zsh-newuser-install or
# Powerlevel10k configuration wizard.
#   notty - no terminal, stdin from /dev/null; stderr is checked on its own.
#   tty   - docker run -t, so the code paths that only run on a terminal (the
#           wizards, the p10k instant prompt) run too. stdout and stderr are
#           merged by the pty. `timeout --foreground` keeps zsh in the
#           foreground process group; plain timeout would get it stopped on
#           the tty. An interactive zsh ignores SIGTERM, hence the
#           SIGKILL follow-up (-k).
check_zsh() {
    local name=$1 mode=$2 rc=0 out err errfile
    shift 2
    errfile=$(mktemp)
    if [[ "$mode" == tty ]]; then
        # shellcheck disable=SC2016 # expanded inside the container
        out=$(in_image -t -e TERM=xterm-256color "$@" -- \
            'stty cols 120 rows 40; timeout --foreground -k 5 "$1" zsh -ic "$2"' \
            "$SMOKE_TIMEOUT" "$ZSH_PROBE" 2>"$errfile" </dev/null) || rc=$?
        out=${out//$'\r'/}
    else
        # shellcheck disable=SC2016 # expanded inside the container
        out=$(in_image -e TERM=xterm-256color "$@" -- \
            'timeout -k 5 "$1" zsh -ic "$2"' \
            "$SMOKE_TIMEOUT" "$ZSH_PROBE" 2>"$errfile" </dev/null) || rc=$?
    fi
    err=$(cat "$errfile")
    rm -f "$errfile"

    # What zsh printed besides the marker line: stderr, plus in tty mode
    # everything else that came through the pty.
    local noise=$err
    if [[ "$mode" == tty ]]; then
        noise=$(grep -v '^NETSHOOT_ZSH_OK$' <<<"$out"$'\n'"$err" || true)
    fi

    local wizard='newuser|zsh-newuser-install|Z Shell configuration function|configuration wizard|p10k configure'
    local errors='error|not found|no such file|permission denied|insecure|denied|cannot|can.t|unable|failed|warning'
    if grep -qiE "$wizard" <<<"$out"$'\n'"$err"; then
        fail "$name" "configuration wizard shown"$'\n'"$out"$'\n'"$err"
    elif [[ $rc -eq 124 || $rc -eq 137 ]]; then
        fail "$name" "timed out after ${SMOKE_TIMEOUT}s (waiting for input?)"$'\n'"$out"$'\n'"$err"
    elif [[ $rc -ne 0 ]]; then
        fail "$name" "exit code $rc (bundled config not loaded?)"$'\n'"$out"$'\n'"$err"
    elif ! grep -qx 'NETSHOOT_ZSH_OK' <<<"$out"; then
        fail "$name" "bundled zsh configuration not loaded (no probe marker)"$'\n'"$out"$'\n'"$err"
    elif grep -qiE "$errors" <<<"$noise"; then
        fail "$name" "error output"$'\n'"$noise"
    else
        pass "$name"
        if [[ -n "$noise" ]]; then
            printf '        (other output, not an error)\n'
            printf '%s\n' "$noise" | sed 's/^/        /'
        fi
    fi
}

# ------------------------------------------------------------------------------
# Checks
# ------------------------------------------------------------------------------

echo "Smoke testing ${IMAGE} as variant '${VARIANT}'"
echo

echo "== Binaries"
if [[ "$VARIANT" == slim ]]; then
    check_binaries present "${SLIM_PRESENT[@]}"
    check_binaries absent "${SLIM_ABSENT[@]}"
else
    check_binaries present "${FULL_PRESENT[@]}"
    check_binaries absent "${FULL_ABSENT[@]}"
fi

echo
echo "== Functional"
check "witr --version" -- 'witr --version'
check "check-tls --help as uid 1000" --user 1000:1000 -- 'check-tls --help'
check "install scripts are not left in the image" -- \
    '! compgen -G "/tmp/install-*.sh" >/dev/null && [[ ! -e /tmp/scripts ]]'
check "no zsh configuration in /root" -- \
    '[[ ! -e /root/.zshrc && ! -e /root/.p10k.zsh && ! -e /root/.oh-my-zsh ]]'
if [[ "$VARIANT" != slim ]]; then
    check "grpcurl --version" -- 'grpcurl --version'
    check "doggo --version" -- 'doggo --version'
    check "websocat --version" -- 'websocat --version'
    check "kubectl version --client" -- 'kubectl version --client'
    check "python3 -m venv in /tmp as uid 1000" --user 1000:1000 -- \
        'python3 -m venv /tmp/venv && /tmp/venv/bin/python -c "import sys; print(sys.prefix)"'
    check "man -w tcpdump" -- 'man -w tcpdump'
fi
check_zsh "zsh loads the bundled config as root" notty
check_zsh "zsh loads the bundled config as uid 1000" notty --user 1000:1000
check_zsh "zsh on a tty as root" tty
check_zsh "zsh on a tty as uid 1000" tty --user 1000:1000

case "$VARIANT" in
    docker)
        echo
        echo "== Variant: docker"
        check "docker --version" -- 'docker --version'
        check "docker buildx version" -- 'docker buildx version'
        check "docker compose version" -- 'docker compose version'
        # CLI only: no engine and no containerd in this variant.
        check_binaries absent dockerd containerd
        ;;
    podman)
        echo
        echo "== Variant: podman"
        check "podman --version" -- 'podman --version'
        ;;
    nerdctl)
        echo
        echo "== Variant: nerdctl"
        check "nerdctl --version" -- 'nerdctl --version'
        ;;
    containerd)
        echo
        echo "== Variant: containerd"
        check "containerd --version" -- 'containerd --version'
        check "nerdctl --version" -- 'nerdctl --version'
        ;;
    *) ;;
esac

echo
echo "Summary: ${passed} passed, ${failed} failed"
[[ $failed -eq 0 ]] || exit 1
