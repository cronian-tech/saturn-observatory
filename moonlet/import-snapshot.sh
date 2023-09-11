#!/bin/bash

set -e

# This script assumes that VictoriaMetrics container is already running.
# If it's not start it with the following command:
# docker compose -f moonlet/compose.yaml up -d

# Un-tar Prometheus snapshot into the anonymous volume.
docker run --rm --volumes-from moonlet-vm-1 -w /snapshot -v "$(pwd)/snapshot.tar.gz:/snapshot.tar.gz" busybox \
    tar -xzf /snapshot.tar.gz --strip 1

# Import the snapshot into VictoriaMetrics.
docker run --rm -it --volumes-from moonlet-vm-1 --network container:moonlet-vm-1 victoriametrics/vmctl:v1.93.3 \
    prometheus \
    --prom-snapshot /snapshot \
    --prom-filter-time-start=2023-08-01T00:00:00Z \
    --prom-filter-time-end=2023-08-31T00:00:00Z
