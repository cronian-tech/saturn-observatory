#!/bin/bash

set -e

source "$(dirname "$0")/config.sh"

# Use hive partitioning.
# See https://duckdb.org/docs/data/partitioning/hive_partitioning#hive-partitioning
DATA_DIR="data/year=2023/month=8"

# Export metrics from VictoriaMetrics to CSV on the host.
METRIC_NAME=saturn_node_info
METRIC_FORMAT=__timestamp__:rfc3339,id,state,core,ip_address,sunrise,cassini,geoloc_region,geoloc_city,geoloc_country,geoloc_country_code,sppedtest_isp,sppedtest_server_location,sppedtest_server_country
curl --create-dirs http://localhost:8428/api/v1/export/csv \
    -o "${DATA_DIR}/${METRIC_NAME}.csv" \
    -d "format=${METRIC_FORMAT}" \
    -d "match[]=${METRIC_NAME}"

# Add header and gzip.
sed -i '' -e "1s/^/${METRIC_FORMAT}\n/" "${DATA_DIR}/${METRIC_NAME}.csv"
gzip "${DATA_DIR}/${METRIC_NAME}.csv"
