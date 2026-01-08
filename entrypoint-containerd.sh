#!/usr/bin/env bash
#
# Entrypoint script for the containerd-enabled Netshoot image.
#
# This script starts the containerd daemon in the background, redirecting its
# logs to /var/log/containerd.log. It then executes any command passed to the
# container, allowing the user to run a shell or other tools while containerd
# is running.
#
# Maintainer: Grégoire Compagnon (obeone) <obeone@obeone.org>
#

set -e

# Start containerd in the background.
containerd > /var/log/containerd.log 2>&1 &
CONTAINERD_PID=$!

# Wait a moment for containerd to start.
sleep 2

# Check if containerd is still running.
if ! kill -0 "$CONTAINERD_PID" 2>/dev/null; then
    echo "ERROR: containerd failed to start. Check /var/log/containerd.log for details:" >&2
    tail -n 20 /var/log/containerd.log >&2
    exit 1
fi

echo "INFO: containerd started successfully (PID: $CONTAINERD_PID)"

# Execute the command provided to the docker run command.
# This allows the container to run interactively (e.g., a shell) or execute a specific command.
exec "$@"
