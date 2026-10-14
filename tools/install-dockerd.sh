#!/usr/bin/env bash

####################################################################
#
# Script Name:   install-dockerd
# Description:   Install the Docker engine (dockerd + containerd) on demand
#                in the netshoot docker variant, which ships the CLI only.
# Author:        Grégoire Compagnon (obeone)
# License:       MIT License
#
# Usage:
#                install-dockerd [--start]
#
# Notes:
#                - Must run as root. The Docker apt repository is already
#                  configured in the image, only the package lists are missing.
#                - --start launches dockerd in the background and waits for
#                  its socket. Running an engine needs a privileged container
#                  (docker run --privileged ...).
#
####################################################################

set -euo pipefail

LOG_FILE=/var/log/dockerd.log
SOCKET=/var/run/docker.sock

# usage
#   Print the help text.
usage() {
    sed -n 's/^# \{0,1\}//; 11,19p' "$0"
}

# start_dockerd
#   Launch dockerd in the background and wait up to 30 s for its socket,
#   so the caller can use `docker` right after this script returns.
start_dockerd() {
    if [[ -S "$SOCKET" ]] && docker info >/dev/null 2>&1; then
        echo "dockerd is already running."
        return 0
    fi
    nohup dockerd >"$LOG_FILE" 2>&1 &
    for _ in $(seq 30); do
        if docker info >/dev/null 2>&1; then
            echo "dockerd is running (logs: $LOG_FILE)."
            return 0
        fi
        sleep 1
    done
    echo "dockerd did not come up in 30 s. Is the container --privileged?" >&2
    tail -n 20 "$LOG_FILE" >&2 || true
    return 1
}

START=false
case "${1:-}" in
    "") ;;
    --start) START=true ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

if [[ $EUID -ne 0 ]]; then
    echo "install-dockerd must run as root." >&2
    exit 1
fi

if ! command -v dockerd >/dev/null 2>&1; then
    # Lists are not kept in the image (they live in a build cache mount).
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        containerd.io \
        docker-ce
fi

if [[ "$START" == true ]]; then
    start_dockerd
else
    echo "Docker engine installed. Start it with: install-dockerd --start"
fi
