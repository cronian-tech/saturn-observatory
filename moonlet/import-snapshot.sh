#!/bin/bash

set -e

source "$(dirname "$0")/config.sh"

# Start VictoriaMetrics container with a named volume for its data and an anonymous volume for Prometheus snapshot.
docker run --name victoria-metrics -p 127.0.0.1:8428:8428 -v victoria-metrics-data:/victoria-metrics-data -v /snapshot -d victoriametrics/victoria-metrics:${VM_VERSION}

# Un-tar Prometheus snapshot into the anonymous volume.
docker run --rm --volumes-from victoria-metrics -w /snapshot -v "$(pwd)/snapshot.tar.gz:/snapshot.tar.gz" busybox \
    tar -xzf /snapshot.tar.gz --strip 1

# Import the snapshot into VictoriaMetrics.
docker run --rm -it --volumes-from victoria-metrics --network container:victoria-metrics victoriametrics/vmctl:${VM_VERSION} \
    prometheus \
    --prom-snapshot /snapshot \
    --prom-filter-time-start=2023-08-01T00:00:00Z \
    --prom-filter-time-end=2023-08-31T00:00:00Z
