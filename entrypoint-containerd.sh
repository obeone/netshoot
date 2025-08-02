#!/usr/bin/env bash
#
# Entrypoint script for the containerd-enabled Netshoot image.
#
# This script starts the containerd daemon in the background, redirecting its
# logs to /var/log/containerd.log. It then executes any command passed to the
# container, allowing the user to run a shell or other tools while containerd
# is running.
#

# Start containerd in the background.
containerd > /var/log/containerd.log 2>&1 &

# Execute the command provided to the docker run command.
# This allows the container to run interactively (e.g., a shell) or execute a specific command.
exec "$@"
