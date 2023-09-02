#!/bin/bash

set -e

# Pin VictoriaMetrics version.
VM_VERSION=v1.93.3

# The URL that will be used to export metrics to CSV.
VM_EXPORT_URL=http://localhost:8428/api/v1/export/csv

# Start VictoriaMetrics container with a volume for Prometheus snapshot.
docker run --name victoria-metrics -p 127.0.0.1:8428:8428 -v /snapshot -d victoriametrics/victoria-metrics:${VM_VERSION}

# Un-tar Prometheus snapshot into VictoriaMetrics volume.
docker run --rm --volumes-from victoria-metrics -w /snapshot -v "$(pwd)/snapshot.tar:/snapshot.tar" busybox \
    tar -xvf /snapshot.tar --strip 1

# Import the snapshot into VictoriaMetrics.
docker run --rm -it --volumes-from victoria-metrics --network container:victoria-metrics victoriametrics/vmctl:${VM_VERSION} \
    prometheus \
    --prom-snapshot /snapshot

# Export metrics from VictoriaMetrics container to CSV on the host.
METRIC_NAME=saturn_node_info
METRIC_FORMAT=__timestamp__,id,state,core,ip_address,sunrise,cassini,geoloc_region,geoloc_city,geoloc_country,geoloc_country_code,sppedtest_isp,sppedtest_server_location,sppedtest_server_country
curl --create-dirs ${VM_EXPORT_URL} \
    -o "data/${METRIC_NAME}.csv" \
    -d "format=${METRIC_FORMAT}" \
    -d "match[]=${METRIC_NAME}"
sed -i '' -e "1s/^/${METRIC_FORMAT}\n/" "data/${METRIC_NAME}.csv"

# Remove VictoriaMetrics container and its volume.
docker rm -vf victoria-metrics
