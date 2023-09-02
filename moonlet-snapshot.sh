#!/bin/bash

set -e

# Create a snapshot of all current Prometheus data.
snapshot=$(curl -XPOST http://localhost:9090/api/v1/admin/tsdb/snapshot | jq -er '.data.name')

# Copy the snapshot from Promeheus container volume to the host.
docker run --rm --volumes-from saturn-moonlet-prometheus-1 -v "$(pwd):/snapshot" busybox \
   tar -cvf /snapshot/snapshot.tar -C /prometheus/snapshots "${snapshot}"

# Remove snapshot from Prometheus container volume.
docker exec saturn-moonlet-prometheus-1 rm -r "/prometheus/snapshots/${snapshot}"
