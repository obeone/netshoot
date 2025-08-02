#!/bin/bash

containerd > /var/log/containerd.log 2>&1 &

exec "$@"
